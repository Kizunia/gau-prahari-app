# Voice Assistant Implementation Plan

## Development rule

Follow the repository's existing **inspect → implement → test → verify** workflow. Deliver one working vertical slice at a time. Do not redesign the application, change the mastitis model, or add an assistant backend.

## Phase 0 — Inspect the current source

Before editing code:

- Inspect `main.dart`, Provider setup, `AuthGate`, and `LocaleController`.
- Inspect the current QR scanner and cow-selection navigation.
- Inspect the existing Cow, collar, milk measurement, and analysis-result entities/controllers.
- Inspect Android/iOS manifests and current test structure.
- Check `gau_prahari/.gitignore` and confirm the proposed local config file is not already tracked.
- Confirm the selected speech packages support the project's Flutter/Dart version and target device.

**Exit criterion:** A short implementation note records which existing classes/screens will be reused and any differences from this specification.

## Phase 1 — Add models and SQLite persistence

Implement the conversation/message models, SQLite database, schema migration, and conversation repository described in [Conversation storage](./CONVERSATION_STORAGE.md).

- Create/load a conversation.
- Insert user and assistant messages.
- Retrieve the last 20 messages in chronological order.
- Update conversation timestamps.
- Persist optional action name/outcome.
- Separate histories by local current-user identifier if one is available.

**Test before proceeding:** repository/database tests cover create, insert, reload after reopen, ordering, and conversation deletion if implemented.

## Phase 2 — Add speech input/output wrappers

Add the speech-recognition and TTS packages at compatible versions. Implement services independent of UI widgets.

- Read the current locale from the existing `LocaleController`.
- Map `en`, `hi`, and `mr` to supported recognition/TTS locale identifiers.
- Handle permission denial, unavailable locale, no speech, cancellation, and TTS errors.
- Expose explicit controller states.

**Test before proceeding:** unit/widget tests exercise state transitions where possible, plus manual checks on the target Android device.

## Phase 3 — Create the assistant controller and response model

Implement a typed internal assistant result and controller.

- Accept a finalized recognized transcript.
- Save it to SQLite before making the AI call.
- Retrieve the recent conversation window.
- Attach language and compact screen context.
- Call an injectable `AiAssistantService`.
- Parse and validate the response.
- Save and speak the reply.
- Handle timeout/network/invalid-response failures without crashing.

The provider/model choice must be finalized before implementing the provider-specific request.

**Test before proceeding:** use a fake AI service; do not require an API key for tests.

## Phase 4 — Build the AI HTTP adapter and demo configuration

- Implement the selected provider in `AiAssistantService`.
- Add `lib/core/config/ai_config.dart` locally and ignore it in `gau_prahari/.gitignore`.
- Add a tracked `ai_config.example.dart` containing placeholders only.
- Reuse the current HTTP dependency.
- Apply a request timeout and typed error mapping.
- Ensure logs never include secrets.

**Test before proceeding:** parsing/configuration tests plus a manual valid request with a locally supplied key. No working key should be committed.

## Phase 5 — Add the authenticated voice entry point and first action

- Make the button available across authenticated app screens while keeping login screens free of it.
- Integrate with the existing navigation implementation using the smallest viable mechanism.
- Register only the `scan_cow` action initially.
- Reuse the existing `QrScannerScreen`.
- Speak and store confirmation only after the action handler has been invoked.
- Store the action result with conversation history.

**Exit criterion:** the end-to-end “Scan a cow” scenario works on the target Android device in the selected language.

## Phase 6 — Add screen-aware explanations

- Introduce compact, accurate current-screen context.
- Start with the cow-selection screen and selected-cow state.
- Add explanations for milk tester and analysis result only after their existing state/models are inspected and made available.
- Implement the P1/P2 action entries only when their existing callbacks and preconditions are verified.
- Keep all action execution behind the allowlist.

**Exit criterion:** a contextual question uses current app state and does not hallucinate unavailable values or actions.

## Phase 7 — Verify acceptance and document setup

- Run formatter and Flutter analyzer.
- Run unit/widget tests without a live API key.
- Test on the actual Android demo device with permissions granted and denied.
- Test English, Hindi, and Marathi where the device speech services support them.
- Test app restart, history persistence, new conversation, and AI/network failure paths.
- Review the Git diff to ensure no API secret or unrelated code change is included.

See [Testing and acceptance](./TESTING_AND_ACCEPTANCE.md).

## Required dependency additions

Evaluate compatible versions of:

- `sqflite`
- `path`
- `speech_to_text`
- `flutter_tts`

The project already uses `provider`, `shared_preferences`, and `http`; reuse these unless a concrete need is found. Do not add a state-management framework or backend dependency for this feature.

## Non-goals during implementation

- Do not modify the current FastAPI inference API.
- Do not introduce a new backend for the voice assistant.
- Do not refactor unrelated screens.
- Do not replace existing repositories/controllers when they can be reused.
- Do not add unverified voice commands or arbitrary actions.
- Do not claim the API key is secure merely because the Dart file is ignored by Git.
