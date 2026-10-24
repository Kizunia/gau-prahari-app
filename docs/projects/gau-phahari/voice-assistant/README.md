# Gau-Prahari Voice Assistant

**Status:** Implementation specification  
**Scope:** Hackathon demonstration MVP  
**Implementation mode:** Four gated phases; one phase is implemented and manually accepted before the next begins.

## Purpose

Add a spoken assistant to the existing Gau-Prahari Flutter app so farmers can ask for help in their current app language, hear spoken responses, revisit past conversations, and gradually use supported voice commands to operate the existing workflow.

The interface should be simple, readable, and suitable for people who are not highly familiar with smartphone apps.

## Agreed decisions

| Area                       | Decision                                                                                       |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| Client                     | Flutter/Dart                                                                                   |
| State management           | Existing Provider and ChangeNotifier approach                                                  |
| Speech recognition         | speech_to_text                                                                                 |
| Text-to-speech             | flutter_tts                                                                                    |
| Conversation persistence   | SQLite using sqflite and path                                                                  |
| Language                   | Current LocaleController selection: English (en), Hindi (hi), or Marathi (mr)                  |
| AI provider                | Google Gemini API                                                                              |
| Initial model              | gemini-2.5-flash; verify access and current API contract before implementation                 |
| HTTP                       | Existing http dependency                                                                       |
| App actions                | Fixed Flutter-side allowlist                                                                   |
| Assistant backend          | No new FastAPI endpoint                                                                        |
| Existing inference backend | Leave the current FastAPI mastitis prediction flow unchanged                                   |
| API key                    | Local Git-ignored Dart config for controlled hackathon demo; exposure in built APK is accepted |
| Scope                      | Demonstration MVP, not production-ready software                                               |

## Four-phase implementation order

1. **Voice foundation and local history:** assistant screen, voice input/output, SQLite, conversation list/reopen, New conversation, and temporary local responder. No Gemini yet.
2. **Gemini integration:** real AI responses, selected language, recent conversation context, local key setup, and API failure handling. No actions executed yet.
3. **Voice action:** execute only the allowlisted scan_cow action to open the existing QR scanner.
4. **Screen awareness:** current-screen context, selected cow, collar/milk/analysis context where available, localized UX, and full regression checks.

The complete manual procedures, acceptance gates, and copy-ready Antigravity requests are in [FOUR_PHASE_IMPLEMENTATION.md](./FOUR_PHASE_IMPLEMENTATION.md).

## Important workflow rule

The project owner manually tests the app after each phase and explicitly accepts it before requesting the next phase. The coding agent must not implement multiple phases in one go, skip failed criteria, or claim tests passed without running them.

## Documentation map

- [Four-phase implementation and manual acceptance](./FOUR_PHASE_IMPLEMENTATION.md)
- [Architecture](./ARCHITECTURE.md)
- [Conversation storage](./CONVERSATION_STORAGE.md)
- [AI integration](./AI_INTEGRATION.md)
- [Voice and localization](./VOICE_AND_LOCALIZATION.md)
- [Actions and screen context](./ACTIONS_AND_CONTEXT.md)
- [Implementation plan](./IMPLEMENTATION_PLAN.md)
- [Testing and acceptance](./TESTING_AND_ACCEPTANCE.md)

## Existing integration points

Current source inspected for this specification:

- gau_prahari/lib/main.dart registers AuthController and LocaleController through Provider.
- gau_prahari/lib/core/localization/locale_controller.dart persists the selected locale and supports en, hi, and mr.
- gau_prahari/lib/features/cow_selection/presentation/screens/cow_selection_screen.dart opens the existing QR scanner.
- gau_prahari/lib/features/cow_selection/presentation/screens/qr_scanner_screen.dart contains the current scanner workflow.
- The app uses direct Navigator and MaterialPageRoute calls. Do not introduce a full routing rewrite for this feature.

The codebase is the integration reference. Some older project documents describe a previous prototype scope and may not reflect the current implementation.

## Definition of done

The four phases are complete when the farmer can speak and hear a response in the selected app language where device support exists, browse and persist local conversations, ask context-aware questions grounded in actual app state, and say “Scan a cow” to open the existing QR scanner through an allowlisted action.
