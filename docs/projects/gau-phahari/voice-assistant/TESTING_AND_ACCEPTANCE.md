# Voice Assistant Testing and Acceptance

## 1. Definition of done

The hackathon MVP is accepted when all P0 scenarios pass on the intended Android device:

- The assistant button is available for an authenticated user and is absent from the login flow.
- The microphone starts/stops cleanly and the current app language controls recognition.
- The assistant returns an intelligible spoken response in the selected language when the device supports that voice.
- User transcripts and assistant replies persist in SQLite across an app restart.
- Only the most recent 20 messages are sent as conversation history.
- The assistant can use available current-screen context to answer a basic help question.
- “Scan a cow” opens the existing QR scanner through a validated allowlisted action.
- Action outcomes are stored accurately; the assistant does not claim success for a failed or unexecuted action.
- API/network/permission errors do not crash or block the existing touch-driven app.
- The tests and analyzer can run without a live AI API key.

## 2. Unit tests

### Conversation storage

- Create a conversation on the first user message.
- Insert user and assistant messages.
- Retrieve messages in chronological order.
- Retrieve only the latest 20 messages for AI context.
- Reopen the database and verify messages persisted.
- Update conversation timestamps.
- Keep conversations separated by local owner identifier where used.
- Delete one conversation and its child messages if deletion is implemented.
- Handle an empty database and an initialization/write error.

### AI response parsing

- Parse a valid reply with no action.
- Parse a valid reply with `scan_cow`.
- Reject an empty reply.
- Reject malformed JSON.
- Reject an unknown action name.
- Reject invalid action arguments.
- Treat provider errors and timeouts as typed failures.
- Confirm logs/output do not include the API key.

### Controller and voice state

- A finalized transcript is persisted before the AI request begins.
- A valid reply is persisted and sent to TTS.
- The controller does not start overlapping AI requests.
- Starting a new listening session stops prior TTS output.
- Language selection is read from the existing locale controller.
- API failure produces a fallback message and returns to a usable state.
- The new conversation operation does not delete existing conversations.

## 3. Widget tests

- Microphone control reflects idle/listening/processing/speaking states.
- Permission or recognition errors show useful feedback.
- The user can cancel listening.
- Conversation messages render in their correct order and role.
- New conversation resets active context without deleting history.
- The assistant entry point is not shown when the user is unauthenticated.
- Action failure produces a failure message instead of a false success confirmation.

Use fake speech and AI services in widget tests. Avoid real microphone, TTS, or network calls in automated tests.

## 4. Manual device checklist

### Voice and locale

- [ ] English: recognize a simple command and hear a spoken reply.
- [ ] Hindi: recognize a simple command and hear a spoken reply if device support is available.
- [ ] Marathi: recognize a simple command and hear a spoken reply if device support is available.
- [ ] Change app language and verify the next interaction uses the new setting.
- [ ] Test no speech detected and user cancellation.
- [ ] Test microphone permission denied and permission restored.

### Conversation history

- [ ] Send a user message and receive a reply.
- [ ] Close and reopen the app.
- [ ] Verify that the latest conversation and its messages remain available.
- [ ] Start a new conversation.
- [ ] Verify that starting a new conversation leaves the older conversation intact.
- [ ] Verify the AI request includes no more than the configured recent-message limit.

### Actions and context

- [ ] Say “Scan a cow” from the cow-selection screen.
- [ ] Say “Scan a cow” from another authenticated screen if app-level button coverage is implemented there.
- [ ] Verify the existing QR scanner opens.
- [ ] Verify the spoken instruction uses the selected language.
- [ ] Ask for help on the cow-selection screen and verify the response uses actual screen context.
- [ ] Test an unknown or unsupported action and verify that no navigation occurs.
- [ ] If analysis-result explanations are implemented, verify that the answer only repeats fields present in the actual result.

### Failure handling

- [ ] Disable network and issue an AI request.
- [ ] Test an invalid/missing local API configuration.
- [ ] Test a provider error or quota response where practical.
- [ ] Verify the transcript is retained after an AI failure.
- [ ] Verify the existing cow-selection and analysis workflows still work via touch controls.

## 5. Release/demo checklist

- [ ] Run `dart format` on changed Dart files.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Confirm no working API key is tracked by Git.
- [ ] Confirm the real config path is ignored and the example file contains placeholders only.
- [ ] Review the final Git diff for unrelated changes.
- [ ] Test the built APK on the actual presentation device.
- [ ] Remove/rotate the demo API key after the hackathon.

## 6. Known limits

- Recognition and TTS quality depend on platform services and installed language support.
- Hosted AI responses require network connectivity.
- A key embedded in the Flutter build may be extracted from the APK; this is accepted only for the controlled hackathon demo.
- Conversation history is local to the device installation and is not cloud-synchronized.
- The assistant explains available app output; it does not replace veterinary assessment or the existing prediction pipeline.
