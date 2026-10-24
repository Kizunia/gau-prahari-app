# Voice Interaction and Localization

## 1. Language rule

The assistant must use the language currently selected in the app. Reuse:

`gau_prahari/lib/core/localization/locale_controller.dart`

The current supported language codes are:

| App language code | Language |
|---|---|
| `en` | English |
| `hi` | Hindi |
| `mr` | Marathi |

Do not add language auto-detection for the initial implementation. When the user changes the app language, subsequent speech recognition and generated replies should use the new language. Previously saved messages remain unchanged.

## 2. Proposed packages

- Speech recognition: `speech_to_text`.
- Text-to-speech: `flutter_tts`.

Check the selected package versions and platform setup against the Flutter/Dart version in this repository before implementation. These packages depend on platform capabilities; the availability of a Hindi or Marathi recognition/TTS voice can vary by device and installed speech services.

## 3. Locale mapping

Read the current app locale from `LocaleController.locale.languageCode`; do not maintain a second independent language setting in the voice assistant.

Map the app's language code to the exact locale identifier format expected by the selected plugin. Recognition and TTS plugins may use different identifier formats. Query available locales/voices where supported and select a matching locale. If no matching voice is available, tell the user in the best available localized form that voice support is unavailable and keep text interaction usable.

Do not silently switch to a different language or pretend speech recognition succeeded.

## 4. Interaction lifecycle

The controller should expose a small explicit state model, for example:

- `idle` — ready to accept a voice request.
- `listening` — waiting for speech.
- `processing` — transcript stored and AI request in progress.
- `speaking` — spoken response in progress.
- `error` — recoverable failure with a user-readable message.

Expected lifecycle:

1. Farmer taps the microphone.
2. Request/check microphone and speech-recognition permissions.
3. Start listening in the selected language.
4. Stop on final result, user cancellation, or plugin timeout.
5. Persist the final transcript.
6. Submit it to the assistant controller.
7. Wait for a valid AI response and execute an approved action if present.
8. Persist the reply and speak it in the selected language.
9. Return to `idle`.

Avoid concurrent speech-recognition sessions or overlapping AI requests. When a new listening session starts, stop ongoing TTS output first. Provide a clear way to cancel listening and prevent a stale callback from speaking an old response after the user has started a new request.

## 5. Spoken response style

- Keep the spoken response short; details can also appear as on-screen text.
- Give one step at a time for navigation and hardware workflows.
- Avoid jargon where a simpler phrase works.
- Use the selected locale for both recognition and TTS.
- Do not use voice output as a substitute for displaying a persistent error or important analysis result.
- If a response contains long numerical detail, summarize it verbally and retain the full supported detail on screen.

## 6. Permissions and platform configuration

During implementation, inspect the Android manifest and any other supported platform setup. Add only the microphone/speech permissions and user-facing permission descriptions required by the selected packages and target platforms. For Android, handle runtime permission denial gracefully. If iOS remains a supported build target, add the required iOS usage-description entries as specified by the package documentation.

Do not modify permissions speculatively before choosing package versions. Verify the actual permission requirements and test both granted and denied flows.

## 7. User-visible feedback

The microphone control should make the state easy to understand with icon/label changes. At minimum, visually distinguish listening, processing, and speaking. Use localized short feedback for permission denial, unavailable language voice, no speech detected, network failure, and AI configuration failure.

A failed voice request must not crash the main Gau-Prahari workflow. The farmer should still be able to use existing touch controls.
