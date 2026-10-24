# Voice Assistant Implementation Plan

**Canonical phase plan:** [FOUR_PHASE_IMPLEMENTATION.md](./FOUR_PHASE_IMPLEMENTATION.md)

Implement exactly four phases. Each phase has its own scope, manual test procedure, and acceptance criteria in the canonical guide. The owner tests the app and explicitly accepts a phase before the next phase begins.

## Phase 1 — Voice foundation and local history

Deliver the assistant screen and authenticated entry point; speech-to-text; text-to-speech; the selected app language; SQLite conversations/messages; history list and reopen; New conversation; restore the last-opened conversation; and a temporary local responder.

**Not included:** Gemini integration or app actions.

**Gate:** manual voice and persistence tests pass on the Android device; analyzer/tests pass or failures are explained.

## Phase 2 — Gemini AI integration

Replace the local responder with Gemini using gemini-3.8-flash after verifying current model and REST API details. Add local Git-ignored config plus a tracked placeholder example; send up to 20 recent messages, current selected language, and the new transcript once; handle API errors.

**Not included:** action execution.

**Gate:** real responses and follow-ups work; history survives restart; failures retain transcripts; key is not tracked; no action executes.

## Phase 3 — First app action

Implement typed response parsing and a fixed allowlist with scan_cow as the only executable action. Reuse QrScannerScreen and keep the normal navigation/back stack.

**Not included:** broader screen context or additional actions.

**Gate:** manual voice command opens the actual scanner and all invalid/unknown actions are rejected.

## Phase 4 — Screen awareness and final verification

Provide explicit current-screen context from actual app state; add contextual explanations for cow selection, collar import, milk tester, and analysis result where real data is available; finalize localized errors and regression testing.

**Gate:** answers match actual screen data, stale/missing data is handled honestly, and the voice/history/action flow plus existing app workflows pass regression checks.

## Shared rules

- Inspect the current code before writing. Do not trust older prototype documentation over actual source.
- Keep the existing Provider/ChangeNotifier approach and direct navigation unless a limited change is demonstrably needed.
- Do not change FastAPI or the existing ML model.
- Do not implement a later phase early.
- Test with injectable/fake AI and speech services where automated tests are appropriate.
- Keep the actual API key out of Git; the demo owner accepts APK extraction risk.
- Report the precise files changed and tests actually run.
- The coding agent must stop at each phase gate and wait for the owner's acceptance.
