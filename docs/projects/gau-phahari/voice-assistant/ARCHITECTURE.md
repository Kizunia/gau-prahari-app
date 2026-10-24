# Voice Assistant Architecture

## 1. Architecture principles

1. Keep the feature Flutter-first and small enough for a hackathon demonstration.
2. Reuse Provider/`ChangeNotifier`, the existing locale controller, existing screens, and existing domain models.
3. Keep UI rendering separate from speech, database, AI, and action-execution logic.
4. Treat the AI response as untrusted input. Flutter validates every requested action before executing it.
5. Do not change the current FastAPI mastitis inference contract to support the assistant.
6. Keep this as a demo implementation; avoid infrastructure and abstractions that do not support the agreed use cases.

## 2. High-level flow

```text
Farmer
  |
  v
Voice Assistant Button
  |
  v
Speech Recognition ----> recognized text
  |
  v
VoiceAssistantController
  |   - selected locale
  |   - recent conversation history
  |   - current screen context
  |
  +---------------------------> Local SQLite database
  |
  v
AiAssistantService (Flutter HTTP client)
  |
  v
Hosted AI API
  |
  v
Structured assistant response
  |
  v
Validate response and action allowlist
  |
  +---- reply text ----> save message ----> Text-to-Speech
  |
  +---- supported action ----> action handler ----> existing Flutter screen/controller
                                                  |
                                                  v
                                           updated screen context
```

The API provider/model is an implementation-time decision. The provider-specific request shape should not leak into the controller or UI.

## 3. Proposed feature folder

Follow this structure unless repository inspection reveals a more natural existing convention:

```text
gau_prahari/lib/features/voice_assistant/
├── domain/
│   ├── entities/
│   │   ├── conversation.dart
│   │   └── chat_message.dart
│   └── services/
│       └── assistant_action.dart
├── data/
│   ├── database/
│   │   └── conversation_database.dart
│   ├── repositories/
│   │   └── conversation_repository_impl.dart
│   ├── models/
│   │   └── assistant_response_dto.dart
│   └── services/
│       ├── speech_recognition_service.dart
│       ├── speech_output_service.dart
│       └── ai_assistant_service.dart
└── presentation/
    ├── controllers/
    │   └── voice_assistant_controller.dart
    └── widgets/
        └── voice_assistant_button.dart
```

This is a guide, not a reason to create empty layers. Use the smallest set of files that keeps responsibilities clear.

## 4. Responsibilities

### VoiceAssistantButton

- Presents a clear microphone affordance and current listening/processing state.
- Starts or stops listening through the controller.
- Exposes a concise status or error to the user.
- Does not call the AI API, open the database, or navigate on its own.

### VoiceAssistantController

- Coordinates speech recognition, local history, AI requests, action execution, and spoken output.
- Reads the selected language from `LocaleController`.
- Builds each AI request from recent messages and available screen context.
- Persists user and assistant messages.
- Handles loading/error state and prevents overlapping requests.
- Executes only actions accepted by the action registry.

### ConversationRepository

- Creates/loads conversations.
- Inserts messages and updates conversation timestamps.
- Retrieves recent messages in chronological order for the AI request.
- Exposes history to the controller without putting SQL in widgets.

### Speech services

- Wrap the chosen speech-to-text and text-to-speech packages behind simple Dart interfaces.
- Convert the selected app language to a supported platform locale identifier.
- Surface permission, availability, and recognition errors to the controller.

### AiAssistantService

- Sends the user transcript, recent conversation, language code, and sanitized screen context to the selected hosted AI provider.
- Parses the provider response into a typed result.
- Applies timeouts and returns typed errors.
- Does not directly navigate or invoke hardware.

### Assistant action registry

- Maps fixed action names to Flutter callbacks.
- Checks whether an action is supported in the current context.
- Calls existing screens/controllers; it must not duplicate their feature logic.
- Returns success/failure to the controller so the reply and history remain truthful.

## 5. App-wide entry point

The intended interaction is available on authenticated screens, not on login/register screens.

The current app has an `AuthGate`, a `MaterialApp`, and screens that push `MaterialPageRoute` directly. Inspect these exact integration points before implementation. Add the smallest viable app-level entry point or authenticated-screen wrapper that keeps the button available while existing routes are pushed.

If a root navigator key or observer is introduced, use it only to support the assistant's known navigation/context needs. Do not migrate all screens to named routes solely for this feature.

## 6. Context and action boundaries

The assistant request can include only facts the application currently knows, such as:

- Current screen or workflow step.
- Selected cow ID and other relevant fields that already exist in the screen state.
- Whether collar history is available.
- Existing milk measurement or analysis result, if that data is available in memory.

Do not re-derive a prediction, fabricate sensor measurements, or treat generated/simulated values as real measurements. Explain the current app result; do not generate an independent diagnosis.

See [Actions and screen context](./ACTIONS_AND_CONTEXT.md).

## 7. Network and backend boundary

- The assistant calls a hosted AI API directly from Flutter using the existing `http` dependency unless repository inspection gives a concrete reason to select another client.
- Do not create an assistant endpoint in FastAPI for the MVP.
- Keep the existing FastAPI analysis API and its model behavior unchanged.
- An AI call requires network connectivity. The local history remains available offline; AI-generated replies do not.
- If the API is unavailable, provide a short localized fallback message and preserve the user's transcript in local history.

## 8. Dependencies to evaluate

The existing Flutter manifest already includes `provider`, `shared_preferences`, and `http`. Evaluate compatible versions of:

- `sqflite` — SQLite persistence.
- `path` — database path construction.
- `speech_to_text` — speech recognition.
- `flutter_tts` — spoken responses.

Do not add dependencies until implementing the corresponding milestone. Check current Flutter/Dart compatibility and platform setup before choosing versions.
