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