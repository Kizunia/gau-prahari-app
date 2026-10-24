# Gau-Prahari Project Documentation

This directory contains technical specifications for the Gau-Prahari application.

## Documents

### Project
- [PROJECT_CONTEXT.md](./PROJECT_CONTEXT.md)
- [APP_REQUIREMENTS.md](./APP_REQUIREMENTS.md)

### Data
- [DATA_CONTRACT.md](./DATA_CONTRACT.md)

### Hardware
- [BLE_SPEC.md](./BLE_SPEC.md)

### Backend
- [BACKEND_API.md](./BACKEND_API.md)

### Machine Learning
- [ML_MODEL.md](./ML_MODEL.md)

### Development
- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)

### Voice Assistant
The current four-phase Flutter voice-assistant specification is maintained separately. Implement one phase at a time and use its manual acceptance checklist before advancing.

- [Voice Assistant Overview](./voice-assistant/README.md)
- [Four-Phase Implementation and Manual Acceptance](./voice-assistant/FOUR_PHASE_IMPLEMENTATION.md)
- [Architecture](./voice-assistant/ARCHITECTURE.md)
- [Conversation Storage](./voice-assistant/CONVERSATION_STORAGE.md)
- [Gemini AI Integration](./voice-assistant/AI_INTEGRATION.md)
- [Voice and Localization](./voice-assistant/VOICE_AND_LOCALIZATION.md)
- [Actions and Screen Context](./voice-assistant/ACTIONS_AND_CONTEXT.md)
- [Implementation Plan](./voice-assistant/IMPLEMENTATION_PLAN.md)
- [Testing and Acceptance](./voice-assistant/TESTING_AND_ACCEPTANCE.md)

---

## Current prototype note

Some sections below and in older project documents describe an earlier Round II prototype scope and may be outdated. The current Flutter source code is the integration reference for which screens/features presently exist. In particular, the current code contains QR-scanning functionality; do not assume it is excluded merely because an older requirements document says so.

## Development principle

    TEST -> VERIFY -> PROGRESS

Use the smallest implementation that satisfies the current phase. Keep changes separately testable, do not alter the existing model/inference contract for the voice assistant, and avoid unrelated refactors.
