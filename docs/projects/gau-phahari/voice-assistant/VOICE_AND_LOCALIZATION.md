# Voice Interaction and Localization

## 1. Language rule

Use the existing LocaleController as the single source of selected language. Current supported codes are English (en), Hindi (hi), and Marathi (mr). Do not implement automatic speech-language detection in this MVP.

Read the current app language for each new request and map it to an identifier supported by the chosen speech-recognition and TTS plugin. The plugins may use different locale-ID formats. Check device support instead of assuming a voice is installed.

Existing localization uses AppLocalizations and JSON files in the app's language assets. New assistant UI strings must use the existing localization mechanism. Do not hard-code user-facing status/error labels only in English.

## 2. Packages

- speech_to_text for speech recognition.
- flutter_tts for spoken replies.

Confirm package versions and platform setup are compatible with the repository's Flutter/Dart SDK before adding them. For this MVP, speech-to-text and speech output run through the device/plugin; no separate speech API key is planned.

## 3. User-facing states

Provide visible and localized states for:
- Idle / ready.
- Listening.
- Processing.
- Speaking.
- Recoverable error.

Also localize microphone permission denied, no speech detected, cancelled, language/voice unavailable, network failure, Gemini API/configuration failure, and unsupported command feedback.

The assistant interface must display text as well as speak replies. Do not rely on voice alone for important result/error details.

## 4. Interaction lifecycle

1. User taps the microphone.
2. Stop any prior TTS output and request/check microphone permission.
3. Start recognition in the selected language.
4. Stop on final result, cancellation, plugin timeout, or user action.
5. Persist the recognized transcript.
6. In Phase 1, use the temporary local responder. In Phase 2 onward, call Gemini.
7. Validate the response and, starting in Phase 3, dispatch any allowed action through the designated Flutter handler.
8. Persist the response/action outcome.
9. Speak the response in the currently selected language and return to idle.

Prevent overlapping recognition sessions, duplicate requests caused by repeated taps, and stale callbacks speaking a response from a superseded request. Support cancellation with a clear visible state.

## 5. Device capability and fallback

Recognition and TTS support for Hindi/Marathi depends on the Android device and installed speech services. On an unsupported language, explain the limitation in the best available localized form and keep touch-based app controls usable. Do not silently change the user's language or pretend recognition succeeded.

Before implementation, inspect the target-platform manifests and plugin documentation. Add only permissions/configuration actually required by the selected package versions. Test permission-granted and permission-denied behavior on the real demo device.

## 6. Speech response style

- Keep spoken responses short and actionable.
- Give one workflow step at a time.
- Preserve the original language of old messages when the app's language changes.
- Use the currently selected language for new replies, UI feedback, and TTS where supported.
- Do not claim an action succeeded before the actual Flutter action handler reports success.
