# Voice Assistant Architecture

## 1. Architecture principles

- Keep the feature Flutter-first and small enough for a hackathon.
- Reuse Provider, ChangeNotifier, LocaleController, existing screens, and existing domain models.
- Separate UI, speech services, SQLite storage, AI transport, and app-action execution.
- Treat model output as untrusted. Flutter validates action names, arguments, and preconditions.
- Do not modify the existing FastAPI prediction endpoint or ML model.
- Build the system incrementally in the four phases described in [FOUR_PHASE_IMPLEMENTATION.md](./FOUR_PHASE_IMPLEMENTATION.md).

## 2. High-level flow

Farmer speaks → speech recognition → VoiceAssistantController → persist transcript → retrieve recent history → AiAssistantService → Gemini API → normalize/validate reply → persist reply → display and speak reply.

Starting in Phase 3, a valid allowlisted action may be returned from the assistant screen to the invoking authenticated screen, which dispatches the action through existing Flutter navigation. Only scan_cow is executable in Phase 3. Phase 4 adds contextual guidance grounded in real app state.

## 3. Proposed folder structure

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
        ├── screens/
        │   └── voice_assistant_screen.dart
        └── widgets/
            └── voice_assistant_button.dart

This is a guide, not a requirement to create empty layers. Prefer the smallest structure that keeps responsibilities clear and matches repository conventions.

## 4. Responsibilities

### Voice assistant screen and entry point

- The entry point is an app-bar action (or equivalent small top-level entry point) on authenticated workflow screens: cow selection, collar import, milk tester, and analysis result.
- Do not display the entry point on login/register screens or while the QR scanner is active.
- The assistant screen shows a message transcript, microphone control, voice state, New conversation, and a simple history list so previous conversations can be reopened.
- Interface messages and controls use the existing localization system.

### VoiceAssistantController

- Coordinates speech, local conversation history, AI requests, response presentation, and action requests.
- Reads the selected language from LocaleController.
- Prevents overlapping recognition sessions and duplicate AI requests.
- Saves user messages before the network request and assistant replies after successful parsing.
- Receives only available screen context and validated action results.

### ConversationRepository

- Creates and loads conversations.
- Saves messages and action outcomes.
- Retrieves the latest 20 messages for the active conversation in chronological order.
- Updates conversation timestamps, including last-opened time.
- Keeps SQL out of widgets.

### Speech services

- Wrap speech_to_text and flutter_tts behind small Dart services.
- Map the selected app language to the locale identifiers supported by each plugin.
- Handle microphone permission, unavailable locales, recognition cancellation, no speech, and TTS failures.

### AiAssistantService

- Encapsulates provider-specific Gemini request/authentication/response parsing.
- Receives the current locale, latest transcript, recent history, and only the approved context fields for the current phase.
- Uses a timeout and typed errors.
- Does not navigate or call hardware services directly.

### Action dispatch

- Keep a fixed allowlist and typed action response.
- The assistant screen requests an action; the host authenticated workflow dispatches it through a known Flutter callback, preserving natural back-stack behavior.
- The model cannot provide a route, method name, URL, SQL statement, or code to execute.
- Use the existing QrScannerScreen for scan_cow.
- Report action success only after the Flutter handler confirms that the action was invoked.

## 5. Authenticated-screen integration

The current app creates MaterialApp in main.dart and uses direct Navigator.push(MaterialPageRoute(...)) calls. Add the reusable assistant entry point to the identified authenticated workflow screens rather than migrating the whole app to named routes or building a global overlay that could cover the camera.

When an action is requested, close/return from the assistant screen in a controlled way and let the invoking screen dispatch it. Validate that the scanner opens without leaving the assistant UI in an unexpected position in the navigation stack.

## 6. Context boundary

Only add data known to the application: current screen, selected Cow, collar-history availability, current milk-measurement availability, and actual AnalysisResult fields where in scope. The source currently passes Cow to collar-import/milk tester/result screens and passes MilkMeasurement and AnalysisResult to the result screen. These objects are not automatically available to an app-wide controller; the owning screen must publish or provide the context explicitly.

Never invent sensor readings, model scores, results, or diagnoses. Clear or replace context when the screen/workflow changes.

## 7. Network and backend boundary

- The assistant makes hosted AI requests directly from Flutter.
- No new assistant-specific FastAPI endpoint.
- The existing FastAPI inference flow remains unchanged.
- SQLite history is available offline; Gemini responses require network access.
- On network/API failure, keep the transcript saved, display a localized error/fallback, and keep touch-based app workflows usable.

## 8. Dependencies

The existing Flutter manifest includes provider, shared_preferences, http, and mobile_scanner. Evaluate compatible versions of sqflite, path, speech_to_text, and flutter_tts before adding them. Do not add a new state-management framework or dependencies unrelated to this feature.
