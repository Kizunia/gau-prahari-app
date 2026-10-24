# gau_prahari

## Voice assistant Gemini setup

The assistant uses Google's Gemini API directly for the SIH demo. After a fresh
clone, copy `lib/core/config/ai_config.example.dart` to
`lib/core/config/ai_config.dart` and put the demo key in `geminiApiKey`. The real
config file is ignored by Git. Leave the key blank to run analyzer and tests;
tests use fake responders and do not contact Gemini. A key embedded in a demo
APK can be extracted, so use a restricted demo key and rotate it after the event.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
