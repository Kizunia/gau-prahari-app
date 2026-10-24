# Gau-Prahari Project Documentation

This directory contains the technical specification for the Gau-Prahari application.

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

The Flutter voice-assistant MVP is specified separately. It uses local SQLite conversation history, speech input/output, the selected app language, and allowlisted actions against existing app screens.

- [Voice Assistant Specification](./voice-assistant/README.md)
- [Architecture](./voice-assistant/ARCHITECTURE.md)
- [Conversation Storage](./voice-assistant/CONVERSATION_STORAGE.md)
- [AI Integration](./voice-assistant/AI_INTEGRATION.md)
- [Voice and Localization](./voice-assistant/VOICE_AND_LOCALIZATION.md)
- [Actions and Screen Context](./voice-assistant/ACTIONS_AND_CONTEXT.md)
- [Implementation Plan](./voice-assistant/IMPLEMENTATION_PLAN.md)
- [Testing and Acceptance](./voice-assistant/TESTING_AND_ACCEPTANCE.md)

---

## Current Prototype

The Round II prototype intentionally uses a simplified architecture:

    Collar History File
            |
            v
       Flutter App
            ^
            |
        BLE/GATT
            |
     Milk Tester ESP32
            |
            v
       MilkMeasurement
            |
            v
         FastAPI
            |
            v
        Existing ML
            |
            v
        Prediction
            |
            v
       Flutter Result

### Intentionally excluded

- QR scanning
- Collar BLE
- Cloud infrastructure
- Authentication
- Dashboards
- Production forecasting
- New ML model

---

## Development Principle

    TEST -> VERIFY -> PROGRESS

The complete pipeline should first work using:

    MockMilkTester

before replacing it with:

    BleMilkTester

The rest of the application must not depend on the hardware implementation.

> **Documentation note:** The prototype exclusions and scope described above capture an earlier Round II snapshot. For feature availability and integration decisions, inspect the current Flutter source; newer code may already implement some listed items.
