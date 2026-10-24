# Gau-Prahari Voice Assistant

**Document status:** Implementation specification  
**Scope:** Hackathon demonstration MVP  
**Code status:** Documentation only; application implementation is a separate step

## 1. Purpose

Add a voice assistant to the existing Gau-Prahari Flutter application so a farmer can ask for help in plain language, hear a spoken response, and perform a small set of supported actions without needing to navigate every screen manually.

The experience is intended for digitally less-literate users. Instructions should be concise, friendly, sequential, and expressed in the language currently selected in the app.

## 2. Agreed decisions

| Area | Decision |
|---|---|
| Client architecture | Implement the assistant feature in Flutter/Dart |
| State management | Reuse the project's existing Provider and `ChangeNotifier` approach |
| Speech input | Use a Flutter speech-recognition package, proposed: `speech_to_text` |
| Spoken output | Use Flutter text-to-speech, proposed: `flutter_tts` |
| Conversation persistence | SQLite on the device, proposed: `sqflite` |
| Language | Follow the current `LocaleController` setting; no language auto-detection in this phase |
| AI reasoning | Call a hosted AI API directly from Flutter |
| Assistant backend | Do not add a new FastAPI endpoint for the assistant |
| Existing inference backend | Leave the current FastAPI mastitis-prediction flow unchanged |
| App actions | Execute only allowlisted actions that map to existing screens/controllers |
| Credentials | Use a local, Git-ignored Dart config file for the hackathon build, plus a tracked empty example |
| Scope | Optimize for a working demo, not production readiness |

The hosted AI provider and model have not been selected yet. Keep the provider-specific HTTP request and response parsing behind a small service adapter so the choice is contained in one place.

## 3. MVP user experience

1. A voice-assistant button is available on authenticated app screens.
2. The farmer taps the button and speaks.
3. Speech recognition uses the currently selected app language.
4. The assistant sends the recognized text, recent conversation messages, language, and available screen context to the AI service.
5. The assistant receives a reply and, if appropriate, a structured action.
6. Flutter validates the action and invokes an existing app capability.
7. The reply is saved locally and spoken in the selected language.
8. Conversation history remains available after the app is restarted.

### First end-to-end demonstration

Farmer: “Scan a cow.”

Gau-Prahari opens the existing QR scanner and says a short confirmation/instruction. The assistant must not claim the scanner opened until the Flutter action has actually been invoked.

The next useful interaction is a contextual help question such as “What should I do next?” The answer should reflect the current screen and only use state that the app can supply.

## 4. What is included

- A voice-assistant entry point for authenticated users.
- Speech-to-text and text-to-speech.
- Selected-language support for English, Hindi, and Marathi, subject to platform voice availability.
- A persistent local conversation database.
- Recent-message context sent with each AI request.
- Awareness of the current screen and relevant workflow state.
- A small allowlist of app actions, beginning with opening the existing QR scanner.
- Helpful loading, permission, network, and unsupported-command states.
- Unit/widget tests and a manual Android-device acceptance checklist.

## 5. Out of scope

- A production-grade security redesign.
- An on-device large language model.
- Cloud synchronization of conversation history.
- A new assistant-specific FastAPI service.
- Replacing the existing mastitis model or inference API.
- Redesigning the app's navigation or state management wholesale.
- Executing arbitrary code, routes, URLs, or methods supplied by the model.
- Persisting raw audio recordings.

## 6. Documentation map

- [Architecture](./ARCHITECTURE.md) — components and data flow.
- [Conversation storage](./CONVERSATION_STORAGE.md) — local SQLite schema and history behavior.
- [AI integration](./AI_INTEGRATION.md) — request/response contract, prompt behavior, and demo API-key setup.
- [Voice and localization](./VOICE_AND_LOCALIZATION.md) — speech lifecycle and selected-language behavior.
- [Actions and screen context](./ACTIONS_AND_CONTEXT.md) — action allowlist, context model, and navigation constraints.
- [Implementation plan](./IMPLEMENTATION_PLAN.md) — ordered milestones and repository integration points.
- [Testing and acceptance](./TESTING_AND_ACCEPTANCE.md) — definition of done and test scenarios.

## 7. Existing application integration points

Current code inspected for this specification:

- `gau_prahari/lib/main.dart` registers `AuthController` and `LocaleController` through Provider.
- `gau_prahari/lib/core/localization/locale_controller.dart` persists the selected locale and supports `en`, `hi`, and `mr`.
- `gau_prahari/lib/features/cow_selection/presentation/screens/cow_selection_screen.dart` opens the current QR scanner.
- `gau_prahari/lib/features/cow_selection/presentation/screens/qr_scanner_screen.dart` contains the existing scanner flow.
- The existing project uses direct `Navigator` calls in screens; the assistant should integrate with this setup rather than introduce a routing framework.

The codebase is the current integration reference. Some existing project documents describe an earlier prototype scope and may be stale; inspect the implementation before assuming a feature is absent.

## 8. Done means

The MVP is complete when the farmer can speak in the selected language, receive a spoken AI response, reopen the app and see the persisted conversation, ask a context-aware help question, and say “Scan a cow” to open the existing QR scanner through a validated Flutter action.
