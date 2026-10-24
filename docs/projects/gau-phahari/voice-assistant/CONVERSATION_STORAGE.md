# Conversation History and Local Storage

## 1. Decision

Persist conversation text on the device using SQLite, with `sqflite` as the proposed Flutter package. Conversation history must survive app restarts and must not depend on the AI provider being available.

The database is for assistant conversations only. Do not repurpose it as the source of truth for cow medical data, collar telemetry, milk measurements, or analysis records.

## 2. Stored data

Persist:

- Conversation identifier and timestamps.
- User transcript text.
- Assistant reply text.
- Optional screen name associated with a message.
- Optional allowlisted action name and execution outcome.

Do not persist raw audio recordings. Do not store the API key in SQLite. Do not store entire AI request/response payloads if they contain unrelated app or user context.

## 3. Suggested schema

Use UTC Unix epoch milliseconds for timestamps. Adapt names to the repository's existing naming conventions if needed.

### `conversations`

| Column | Type | Purpose |
|---|---|---|
| `id` | TEXT primary key | Stable conversation ID generated on the device |
| `owner_id` | TEXT nullable | Local current-user identifier, if available, to avoid mixing demo users |
| `title` | TEXT nullable | Short local label; may be derived from the first user message |
| `created_at` | INTEGER | Creation time in UTC milliseconds |
| `updated_at` | INTEGER | Time of the latest message |
| `is_archived` | INTEGER | Optional boolean-like flag, default 0 |

### `messages`

| Column | Type | Purpose |
|---|---|---|
| `id` | TEXT primary key | Stable message ID generated on the device |
| `conversation_id` | TEXT not null | References `conversations.id` |
| `role` | TEXT not null | `user` or `assistant` |
| `content` | TEXT not null | Transcript or spoken reply text |
| `created_at` | INTEGER | UTC timestamp in milliseconds |
| `screen_name` | TEXT nullable | Current screen at message time, if known |
| `action_name` | TEXT nullable | Validated action name, when one was attempted |
| `action_status` | TEXT nullable | For example `succeeded`, `failed`, or `not_applicable` |

Recommended database constraints:

- Enable SQLite foreign-key support.
- Add an index on `messages(conversation_id, created_at)`.
- Delete child messages when a conversation is deleted.
- Use a database version and migration path, even though the initial schema is small.

## 4. History behavior

1. On assistant initialization, load the most recently updated non-archived conversation for the current local user.
2. If one does not exist, create a new conversation when the first message is submitted.
3. Save the user's recognized transcript promptly, before waiting for the hosted AI response.
4. Save the assistant reply after the response has been parsed.
5. Save action name/outcome when an action was requested and handled.
6. Update the conversation's `updated_at` timestamp after each new message.
7. Provide a “New conversation” action that creates a fresh conversation. It should not silently delete older history.
8. If a “Delete conversation” action is included, delete that conversation and its messages only after the user explicitly chooses deletion.

If the existing local auth model exposes a stable identifier, use it as `owner_id` only to keep demo users' histories separate on the device. Do not add a new authentication system for this feature.

## 5. Context sent to AI

The database may retain the full local history, but each AI request should include only a bounded recent window—default: the most recent 20 messages for the active conversation, ordered oldest-to-newest within that window.

Include the new user transcript exactly once. Avoid the common bug of sending it once as the latest message and again as an extra prompt string.

The request should also include a compact current-screen context object. See [AI integration](./AI_INTEGRATION.md). Do not send the whole local database or unrelated cow records.

## 6. Restart and error behavior

- After a process restart, the app can recover the most recent conversation from SQLite.
- If the database is empty, create a conversation on demand.
- If a write fails, show a non-blocking error and log a diagnostic without logging secrets.
- If the hosted AI API fails, keep the saved user transcript and add a localized fallback assistant message when appropriate.
- Database initialization failure must not crash app startup; disable history features gracefully and show a clear error.
- If the user switches language mid-conversation, preserve prior messages in their original language and use the currently selected language for new replies.

## 7. Device-local semantics

History is local to that installation and is not synchronized to another phone. It may be removed if the app is uninstalled or its local app data is cleared. Keep a basic way to start a new conversation; conversation deletion is useful but should remain a small feature.

Conversation messages are sent to the selected hosted AI provider when the assistant responds. The UI or README should not imply that messages remain exclusively on the phone after an AI request.
