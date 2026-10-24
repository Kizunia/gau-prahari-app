# Voice Assistant Testing and Acceptance

Use this checklist alongside [FOUR_PHASE_IMPLEMENTATION.md](./FOUR_PHASE_IMPLEMENTATION.md). Phase-specific acceptance is mandatory; the final overall definition of done does not replace the gates.

## Phase 1 — Voice foundation and history

### Manual tests

- [ ] Sign in and verify the assistant entry point appears on authenticated workflow screens and is absent from login/register.
- [ ] Verify the entry point is hidden while the QR scanner is active.
- [ ] Speak a short English phrase; verify recognized text appears.
- [ ] Verify the temporary local response appears, is stored, and is spoken.
- [ ] Reopen the assistant and verify the conversation persists.
- [ ] Start a new conversation; verify older history remains.
- [ ] Reopen an older conversation and verify ordering/content.
- [ ] Restart the app and verify the last-opened conversation restores.
- [ ] Test Hindi/Marathi where available on device.
- [ ] Test permission denial, cancellation, no speech, and unavailable voice.
- [ ] Exercise existing touch workflows.

### Acceptance criteria

- [ ] Voice input and output work for a supported selected locale.
- [ ] SQLite history and reopen/new-conversation behavior work across restart.
- [ ] The phase does not require a Gemini API key.
- [ ] Errors do not crash the app.
- [ ] Existing touch workflows continue to work.
- [ ] flutter analyze and flutter test pass or failures are reported with evidence.

## Phase 2 — Gemini integration

### Manual tests

- [ ] With local config, ask a general question and verify a real Gemini reply appears.
- [ ] Ask a follow-up question and verify recent history is used.
- [ ] Restart the app, reopen the conversation, and continue it.
- [ ] Change selected language and test a new request.
- [ ] Disable networking and verify a localized error and saved transcript.
- [ ] Test missing/invalid local configuration.
- [ ] Verify no action is executed from AI output.
- [ ] Confirm real config is ignored and not committed.

### Acceptance criteria

- [ ] Gemini replies replace the temporary responder.
- [ ] The active conversation's latest 20 messages are ordered correctly and the newest user message appears once.
- [ ] API errors do not crash the app or lose the transcript.
- [ ] Automated tests use fake AI responses and do not require a valid key.
- [ ] No app action executes in Phase 2.
- [ ] No real key is tracked by Git.

## Phase 3 — QR scanner action

### Manual tests

- [ ] Say “Scan a cow” on cow selection and verify the existing QR scanner opens.
- [ ] Verify the assistant screen does not cover the scanner.
- [ ] Verify spoken instruction matches the selected language where supported.
- [ ] Scan the valid demo tag and continue through the existing workflow.
- [ ] Navigate back and check that the route stack is natural.
- [ ] Repeat from another authenticated screen with the assistant entry point.
- [ ] Request an unsupported action and verify no navigation occurs.
- [ ] Verify action outcome appears in local conversation history.

### Acceptance criteria

- [ ] scan_cow is the only executable action.
- [ ] Unknown/malformed actions are rejected.
- [ ] Success is recorded only after the action handler succeeds.
- [ ] Scanner and subsequent app workflow remain functional.
- [ ] Unit tests cover supported, unsupported, and malformed action responses.

## Phase 4 — Context awareness and final integration

### Manual tests

- [ ] Ask what can be done on cow selection; verify answer matches actual controls.
- [ ] Ask which cow is selected during collar import; verify actual ID.
- [ ] Ask what to do next on milk tester; verify it reflects current workflow.
- [ ] Ask for an explanation of an actual analysis result; compare it with the displayed result and measurements.
- [ ] Change cow/screen and ensure prior context is not reused incorrectly.
- [ ] Test missing context; verify the assistant asks or admits it lacks information.
- [ ] Change app language during a conversation and verify new replies follow the current setting.
- [ ] Test rapid repeated inputs, cancellation, permissions, offline/API errors, and restart recovery.
- [ ] Run formatting, flutter analyze, flutter test, and the end-to-end Android demo.

### Acceptance criteria

- [ ] Screen context comes from real app state and is updated/cleared on workflow changes.
- [ ] Contextual explanations match actual objects and do not invent results.
- [ ] Missing/stale context is handled without guessing.
- [ ] Existing touch-based cow, QR, collar, tester, and analysis flows still work.
- [ ] All automated/manual results and remaining limitations are reported accurately.

## Automated test guidance

Test SQLite repository operations, ordered history retrieval, latest-20-message selection, AI response parsing, unknown-action rejection, controller state transitions, duplicate request prevention, error handling, and context lifecycle.

Use fake AI/speech services in automated tests; do not require live microphone access, real TTS, network access, or a real API key to run unit/widget tests.

## Local configuration reminder

A fresh checkout may need a placeholder ai_config.dart copied from the tracked example so Dart imports resolve. A valid key must not be required for analyzer/tests. The real key must remain untracked and is still extractable from a built APK; this is accepted only for the hackathon demo.
