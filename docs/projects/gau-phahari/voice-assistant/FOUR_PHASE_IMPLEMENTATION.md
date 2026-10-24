# Voice Assistant — Four-Phase Implementation and Manual Acceptance Plan

**Purpose:** Give the Antigravity coding agent one implementation phase at a time.  
**Project:** Gau-Prahari Flutter application.  
**Delivery target:** Hackathon demonstration MVP.  
**Rule:** Implement one phase, test it, and stop. The project owner manually accepts the phase before the next phase begins.

## Working rules for every phase

1. Work on a feature branch, not directly on main.
2. Read the linked voice-assistant specification and inspect current source before editing.
3. Implement only the requested phase. Do not pre-implement the following phase.
4. Reuse existing screens, controllers, models, Provider, LocaleController, and navigation wherever practical.
5. Do not modify the FastAPI mastitis inference flow.
6. Run formatting, Flutter analysis, automated tests, and the phase-specific manual checks.
7. Report changed files, commands run, actual results, known limitations, and exact steps the owner should run in the app.
8. If a test cannot be run, say so. Do not claim it passed.
9. Do not begin the next phase until the owner confirms acceptance.

## Phase overview

| Phase | Scope | Must work at the end |
|---|---|---|
| 1 | Assistant screen, speech input/output, SQLite history, local test responder | Speak to a local responder; view, save, reopen, and create conversations |
| 2 | Gemini API integration | Get real AI responses using recent history and selected language |
| 3 | First executable voice action | Saying “Scan a cow” opens the existing QR scanner safely |
| 4 | Current-screen context and final integration | Receive accurate contextual guidance based on real app state |

---

# Phase 1 — Voice foundation and local conversation history

## Objective

Build the usable assistant interface, voice input/output, and persistent local conversation experience. Do not connect Gemini or execute navigation actions in this phase.

## Implementation scope

### A. Assistant entry point and screen

- Add a reusable assistant entry point on the authenticated workflow screens: cow selection, collar import, milk tester, and analysis result.
- Use each screen's existing app-bar action area where available, with a consistent icon and tooltip. If a screen does not have an app bar, use the smallest consistent top-level entry point.
- Do not show the assistant entry point on login/register screens.
- Hide the entry point while the QR scanner is active so it cannot obstruct the camera preview.
- Open a dedicated assistant screen containing a readable message transcript, microphone button, state indicator, New conversation action, and a simple list/entry point for reopening saved conversations.
- Keep the layout accessible and uncomplicated. Do not build elaborate chat features.

### B. Speech

- Use speech_to_text for recognition and flutter_tts for spoken responses.
- Read the selected language from the existing LocaleController: English (en), Hindi (hi), Marathi (mr).
- Handle permission denial, no speech detected, cancellation, unsupported locale, and speech/TTS errors without crashing.
- Prevent simultaneous recognition sessions and stop prior speech output when a new listening session starts.

### C. Local storage

- Use sqflite and path for SQLite database storage.
- Persist conversations and messages with stable IDs, roles, text, and timestamps.
- Save user transcripts and assistant replies.
- Provide a simple conversation history list and allow the user to reopen an older conversation.
- Provide New conversation without deleting the old one.
- Restore the last-opened conversation after app restart.
- Associate records with the existing authenticated user's User.id when available.
- Store no raw audio and no API credentials in SQLite.

### D. Temporary responder

- Use a small, clearly named local test responder.
- When a phrase is recognized, save and display the user's transcript, return a predictable local acknowledgement, save it, and speak it.
- Make it obvious in the code that this responder is temporary and replaced in Phase 2.
- Do not call Gemini in Phase 1.

## Manual test procedure

Perform these tests on the Android device running the app:

1. Log in and verify the assistant entry point appears on the authenticated workflow screens but not on login.
2. Open the assistant and verify the transcript, microphone, and New conversation controls are visible.
3. Grant microphone permission and speak a short English sentence. Confirm the recognized words appear in the transcript.
4. Confirm a local test acknowledgement appears, is saved, and is spoken aloud.
5. Close the assistant and reopen it. Confirm the latest conversation and its messages remain.
6. Start a new conversation. Confirm it starts empty and the previous conversation is still available in history.
7. Open the previous conversation and confirm the messages appear in the right order.
8. Fully close and restart the app. Confirm it restores the last-opened conversation.
9. Repeat recognition/TTS in Hindi and Marathi if those voices are available on the device.
10. Deny microphone permission, cancel listening, and test no-speech behavior. Confirm each case gives useful feedback and the app remains usable.
11. Test the existing cow selection, collar import, milk tester, and analysis touch workflows to ensure the entry-point integration did not break them.

## Phase 1 acceptance criteria

Accept Phase 1 only when all applicable criteria pass:

- [ ] The assistant entry point is available in the authenticated workflow and absent from login/register.
- [ ] It does not obstruct or appear over the active QR scanner.
- [ ] Speech recognition displays a transcript in a supported selected language.
- [ ] A local test response appears and is spoken.
- [ ] Conversations and messages persist in SQLite across app restarts.
- [ ] Previous conversations can be reopened.
- [ ] New conversation does not erase existing history.
- [ ] The last-opened conversation is restored after restart.
- [ ] Permission, cancellation, unavailable-voice, and no-speech cases do not crash the app.
- [ ] Phase 1 works without a Gemini API key.
- [ ] Existing touch-based app workflows still work.
- [ ] flutter analyze and flutter test pass, or any pre-existing/unresolved failure is reported with evidence.

## Antigravity request for Phase 1

Implement **Phase 1 only** from this document. Read the full voice-assistant specification first and inspect the existing source. Build the authenticated assistant entry point, assistant screen, speech recognition/TTS wrappers, SQLite conversation database/repository, conversation history UI, and temporary local responder. Do not integrate Gemini or app-navigation actions yet. Run the required checks and give me precise Android manual test steps plus the actual pass/fail results. Stop after Phase 1 and wait for my acceptance.

---

# Phase 2 — Gemini AI integration

## Objective

Replace the temporary local responder with real Gemini responses while preserving Phase 1 speech, interface, and history behavior.

## Implementation scope

- Use Google Gemini API and the model ID gemini-3.8-flash, after verifying the model and API access against the official current documentation.
- Use the existing http package unless source inspection finds a concrete compatibility reason to change it.
- Keep all provider-specific HTTP, authentication, and parsing code inside AiAssistantService.
- Send the current selected language, the latest user transcript exactly once, up to the latest 20 messages from the active conversation, and only the minimal context available at this phase.
- The assistant should provide helpful natural-language replies only. Do not execute navigation or any other app action in this phase.
- Apply a finite request timeout and handle offline mode, HTTP errors, quota/rate limits, malformed responses, missing configuration, and empty replies.
- Persist the user transcript before the request. Persist a real AI reply after it has been validated.
- Use a fake/injectable AI service so tests do not require a working API key.
- Create a local ignored ai_config.dart and a tracked ai_config.example.dart with placeholders only. Document how to copy the example file into place after a fresh clone. A placeholder config file may be required for Dart compilation, but no valid API key should be required for analyzer/tests.
- Update gau_prahari/.gitignore for the real config path and verify with git check-ignore. Do not commit a working key.
- The team accepts that a key embedded in the demo APK can be extracted. This remains a demo-only trade-off.

Use Google's current official docs:
- Models: https://ai.google.dev/gemini-api/docs/models
- API key use: https://ai.google.dev/gemini-api/docs/api-key
- Function calling, for use in Phase 3: https://ai.google.dev/gemini-api/docs/function-calling

Do not guess an endpoint or response shape. Verify the exact current request/response format for the chosen model before implementing the client.

## Manual test procedure

1. Add the locally configured API key without committing it.
2. Open the assistant and ask “What can you help me with?” Confirm the response is from Gemini, not the Phase 1 local responder.
3. Ask a follow-up such as “Explain that more simply.” Confirm the response reflects recent conversation context.
4. Close and reopen the app and ask a follow-up. Confirm stored history is reused.
5. Change the selected app language to Hindi and ask a new question. Repeat in Marathi if the device speech service supports it.
6. Disable the internet and submit a question. Confirm a helpful error appears and the transcript remains saved.
7. Remove/blank the local key or use invalid configuration. Confirm the app does not crash and tests do not require a valid key.
8. Inspect Git status and Git's ignore check. Confirm the real config file is ignored and not tracked.
9. Confirm no AI reply can open the QR scanner or trigger any other app action yet.

## Phase 2 acceptance criteria

- [ ] Real Gemini responses replace the local test acknowledgement.
- [ ] Up to 20 recent messages are supplied in the correct order, with the current message included only once.
- [ ] The assistant follows the selected language to the extent supported by the model and device voice services.
- [ ] Conversation history survives restarts and is used in follow-up requests.
- [ ] Timeouts, offline state, quota/API errors, and malformed responses are handled without a crash.
- [ ] No actions are executed by model output in this phase.
- [ ] Unit/widget tests use fake AI responses and do not require a real key.
- [ ] The actual API config is ignored by Git and no real key appears in tracked files.
- [ ] flutter analyze and flutter test pass, or remaining failures are documented.

## Antigravity request for Phase 2

Implement **Phase 2 only** from FOUR_PHASE_IMPLEMENTATION.md. Replace the temporary responder with Google Gemini using gemini-3.8-flash after verifying the current official REST API contract. Preserve Phase 1 interface, speech, and SQLite behavior. Add local API configuration and the safe example/ignore rule. Do not execute app actions. Run tests and provide the manual test procedure and actual results. Stop for my acceptance.

---

# Phase 3 — Voice command and QR-scanner navigation

## Objective

Enable the first app action: the farmer can say “Scan a cow” (or an equivalent request in the selected language) and Gau-Prahari opens the existing QR scanner.

## Implementation scope

- Add a typed internal assistant result containing reply text and an optional action.
- Use Gemini structured output/function calling if supported by the verified API contract. Validate all output inside Flutter regardless.
- Register only the scan_cow action in this phase.
- Reject unknown actions, malformed arguments, and invalid preconditions.
- Do not accept arbitrary routes, URLs, method names, code, or SQL from the model.
- Reuse the existing QrScannerScreen and existing navigation conventions.
- Ensure that opening the scanner does not leave the navigation stack in an awkward state. The user should be able to scan/return and continue the existing app flow naturally.
- Do not claim the action succeeded until the Flutter navigation handler confirms it was invoked successfully.
- Persist the action name and execution outcome with the relevant conversation turn.
- Keep the assistant entry point hidden while scanning.

## Manual test procedure

1. From cow selection, open the assistant and say “Scan a cow.”
2. Confirm the actual existing QR scanner opens; verify that the assistant did not create a duplicate scanner screen.
3. Confirm the spoken instruction is in the selected language.
4. Scan a valid demo QR code using the app's existing scanner flow. Verify the existing next screen opens and the user can continue the current cow workflow.
5. Navigate back using the app's normal back controls. Confirm the app does not return to an unexpected overlay or lose its normal workflow.
6. Repeat the command from another authenticated screen where the assistant entry point is exposed.
7. Ask for an unsupported action. Confirm the app does not navigate to an arbitrary screen and instead gives a clear response.
8. Test malformed/unknown action results using a fake AI response in tests.
9. Confirm conversation history records the command, assistant reply, and actual action outcome.
10. Test the scanner command in Hindi and Marathi if recognition is available.

## Phase 3 acceptance criteria

- [ ] scan_cow is the only executable action in this phase.
- [ ] The command opens the existing QR scanner through Flutter code.
- [ ] The scanner is not covered by the assistant UI.
- [ ] The post-scan flow and back-stack behavior remain natural.
- [ ] A successful action is confirmed only after the navigation handler succeeds.
- [ ] Unknown or invalid actions never execute.
- [ ] Action name and result persist in conversation history.
- [ ] The command works from supported authenticated entry points.
- [ ] Automated tests cover accepted/rejected actions.
- [ ] Existing scan, collar import, milk tester, and analysis touch flows still work.

## Antigravity request for Phase 3

Implement **Phase 3 only** from FOUR_PHASE_IMPLEMENTATION.md. Add the typed action response and allowlist, with only scan_cow executable. Connect it to the existing QrScannerScreen and preserve normal navigation/back behavior. Do not add screen-context reasoning or more actions yet. Run action tests and provide the specified manual scanner test steps with actual results. Stop for my acceptance.

---

# Phase 4 — Screen awareness and final end-to-end verification

## Objective

Let the assistant answer questions about the current Gau-Prahari workflow using only real application state.

## Implementation scope

- Implement a small, explicit mechanism for current screens to publish context to the assistant. Do not assume an app-wide controller can read widget-local data automatically.
- Start with cow selection and the active cow. Then support collar-import state, milk-tester state, and the actual analysis result where each value is available.
- Reuse existing Cow, CollarHistory, MilkMeasurement, and AnalysisResult entities; do not duplicate data models.
- Add context-aware help and the documented explanatory actions. Do not add hardware-changing actions unless their existing callback, preconditions, and result are clear.
- Keep action execution allowlisted and validate every action.
- Clear or replace context on navigation so the assistant cannot use stale cow/result data.
- Localize assistant UI states, permission errors, speech errors, unsupported-language feedback, and API errors using the existing app localization mechanism.
- Ensure prior messages stay in their original language while new replies follow the currently selected app language.
- Finish regression tests for voice, history, actions, and existing app workflows.

## Manual test procedure

1. On the cow-selection screen, ask “What can I do here?” Confirm the answer reflects the actual screen controls.
2. Open a particular cow's collar-import flow and ask which cow is selected. Confirm the real cow ID and available details are used.
3. Continue to the milk-tester screen and ask what the next step is. Confirm the answer matches the current workflow and available state.
4. Complete/open an actual analysis result and ask “Explain this result.” Compare the response against the displayed AnalysisResult and actual measurements.
5. Navigate to another cow or screen and ask again. Confirm the assistant no longer refers to stale cow/result data.
6. Test a screen with unavailable context. Confirm the assistant asks a clarifying question or admits that the information is unavailable rather than guessing.
7. Switch the app language mid-conversation. Confirm the next response follows the new selection, while prior history remains unchanged.
8. Repeat key commands in English, Hindi, and Marathi where speech services support them.
9. Test denied microphone permission, cancellation, no speech, offline mode, API quota/error, missing config, and rapid repeated taps.
10. Close/relaunch the app. Verify the last-opened conversation and older saved conversations are available.
11. Run automated tests, dart format, flutter analyze, flutter test, and the main manual end-to-end app flow.
12. Verify existing collar, milk tester, analysis, and QR workflows remain usable through touch controls.

## Phase 4 acceptance criteria

- [ ] Current-screen context reflects actual active application state.
- [ ] Context is refreshed/cleared as navigation or selected cow changes.
- [ ] Cow and analysis explanations match real objects and do not invent values or diagnoses.
- [ ] Missing/stale context does not lead to guessed answers.
- [ ] All supported action execution remains allowlisted.
- [ ] New replies follow the selected app language as supported by model/device; old messages remain intact.
- [ ] Voice, history, action, error, and regression checks pass.
- [ ] App is demonstrable on the intended Android device without a live debugging-only shortcut.
- [ ] Test commands and failures are reported truthfully.

## Antigravity request for Phase 4

Implement **Phase 4 only** from FOUR_PHASE_IMPLEMENTATION.md. Add accurate current-screen context from the existing app state and context-aware guidance for cow selection, collar import, milk testing, and analysis results where the real data is available. Reuse current models and screens. Finish the localization/error handling and end-to-end regression testing. Do not add unverified hardware actions or unrelated features. Provide actual automated-test results and the full manual end-to-end test result. Stop and report any remaining limitations.
