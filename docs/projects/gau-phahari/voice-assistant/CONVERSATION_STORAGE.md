# Conversation History and Local Storage

## 1. Decision

Store conversation text locally in SQLite using sqflite. History must survive normal app restarts and must not depend on the AI service being available. It is conversation history, not the source of truth for cow medical records, telemetry, milk measurements, or analysis results.

## 2. Required user-facing behavior

Phase 1 must include:
- A transcript view showing user messages and assistant replies.
- A New conversation action.
- A simple list of previous conversations.
- The ability to reopen a previous conversation.
- Restoration of the last-opened conversation after app restart.

Starting a new conversation must not delete old conversations. Conversation deletion is optional and is not a P0 requirement.

## 3. Suggested schema

Timestamps use UTC Unix epoch milliseconds. Adjust names to existing conventions where helpful.

### conversations

| Column | Type | Purpose |
|---|---|---|
| id | TEXT primary key | Stable local conversation ID |
| owner_id | TEXT nullable | Existing authenticated User.id, to keep demo users separate |
| title | TEXT nullable | Short label based on first message or a simple default |
| created_at | INTEGER | Creation time |
| updated_at | INTEGER | Time of last message |
| last_opened_at | INTEGER | Updated when the user opens/resumes this conversation |
| is_archived | INTEGER | Optional flag, default 0 |

### messages

| Column | Type | Purpose |
|---|---|---|
| id | TEXT primary key | Stable local message ID |
| conversation_id | TEXT not null | Foreign key to conversations.id |
| role | TEXT not null | user or assistant |
| content | TEXT not null | Recognized transcript or assistant text |
| created_at | INTEGER | Message timestamp |
| screen_name | TEXT nullable | Screen known when the message was submitted |
| action_name | TEXT nullable | Validated action attempted in Phase 3+ |
| action_status | TEXT nullable | succeeded, failed, or not_applicable |

Requirements:
- Enable SQLite foreign keys.
- Add an index on messages(conversation_id, created_at).
- Delete child messages if a conversation is deleted.
- Version the database and support a basic schema migration path.

## 4. Storage lifecycle

1. Create a conversation when the first message is submitted if no active conversation exists.
2. Save the user transcript promptly before starting the AI request.
3. Save the assistant response after validating it.
4. Update updated_at after each message and last_opened_at when a conversation is selected/opened.
5. List conversations for the current local user, ordered by last_opened_at or updated_at as appropriate.
6. Restore the most recently opened conversation at app start when it belongs to the current user; otherwise create one on first use.
7. Keep previous conversations when New conversation is selected.
8. When the current user logs out or another demo user logs in, do not display conversations owned by the other user.

Use the existing User.id where available; do not add a new authentication system.

## 5. AI context window

The local DB may retain the full conversation history. For each Gemini request, supply only the latest 20 messages from the active conversation, ordered oldest-to-newest within that window. Include the current user transcript once, not twice.

The recent message window is a default appropriate for the demo. Do not send the entire local database or unrelated cow records.

## 6. Failure behavior and privacy

- If Gemini fails, retain the user transcript and display a localized error. A fallback assistant message may be saved if it is clearly identified as a fallback and not confused with an AI-generated answer.
- A database initialization/write failure must not crash app startup or the main Gau-Prahari workflow. Show a useful error and make the assistant's storage limitation clear.
- Do not persist raw audio, API keys, authorization headers, or full provider payloads.
- On language change, keep old messages unchanged; new responses follow the current app selection.
- Local history is not synchronized. It may be removed when app data is cleared or the app is uninstalled.
- Conversation text/context is sent to the selected hosted AI provider when requesting a response. Do not claim it stays exclusively on the device.
