# Gau-Prahari — Project Context

## 1. Project Identity

- Project: Gau-Prahari
- Team: HealX
- Smart India Hackathon Problem Statement: SIH26109
- Problem Statement: AI-Based Predictive Modelling for Early Forecasting of Bovine Mastitis in Indian Dairy Farms
- Repository: Kizunia/gau-prahari-app
- Platform: Android
- Mobile framework: Flutter
- Backend: FastAPI
- ML: Existing trained machine-learning model
- Hardware communication: BLE / GATT

---

## 2. Problem

Bovine mastitis is an inflammation of the mammary gland and is one of the major problems affecting dairy cattle.

The system is intended to detect increased mastitis risk as early as possible using a combination of:

1. Longitudinal animal behaviour/environment data from a smart collar.
2. Milk measurements from a handheld milk tester.
3. Machine-learning-based analysis.

The final product is intended to be a low-cost AI + IoT system suitable for Indian dairy farms.

---

## 3. Full Product Vision

The complete Gau-Prahari system is intended to contain two hardware devices.

### 3.1 Smart Neck Collar

The collar continuously collects longitudinal telemetry for each cow.

Hardware:

- ESP32-C3
- LIS3DH 3-axis accelerometer
- MAX30205 temperature sensor
- SHT30 temperature/humidity sensor
- Solar power
- LiFePO4 battery

Potential signals/features:

- Activity
- Movement
- Behavioural trends
- Skin temperature
- Ambient temperature
- Humidity
- Temperature Humidity Index (THI)

The collar is primarily a longitudinal data source.

---

### 3.2 Handheld Milk Tester

The handheld device measures milk-related parameters.

Intended hardware:

- ESP32
- AD5933
- Four-electrode conductivity cell
- DS18B20
- E-201-C glass pH probe
- Optical measurement module

Intended measurements:

- Milk temperature
- Electrical conductivity
- pH
- Somatic Cell Count (SCC)
- Fat %
- SNF %

The milk tester communicates with the Android application through BLE/GATT.

For the current prototype, the ESP32 should be treated as a black box that already has the final measurement values.

---

## 4. Current Round II Prototype

The Round II prototype intentionally simplifies the final product.

The current prototype workflow is:

    Collar history file
          |
          | Import
          v
    Flutter Application
          ^
          |
       BLE/GATT
          |
    Handheld Milk Tester
          |
          v
    MilkMeasurement
          |
          v
    Flutter Application
          |
        HTTPS
          |
          v
       FastAPI
          |
          v
      ML Model
          |
          v
    Prediction JSON
          |
          v
    Flutter Result Screen

---

## 5. What Is Included Now

The prototype MUST support:

1. Selecting a cow.
2. Importing collar history from a local file.
3. Parsing and validating the collar data.
4. Connecting to the actual milk tester over BLE.
5. Receiving milk measurements from the milk tester.
6. Converting raw hardware data into a normalized internal model.
7. Sending analysis data to FastAPI.
8. Running the existing ML model.
9. Returning the model result from FastAPI.
10. Displaying the result in Flutter.
11. Showing actionable interpretation of the model output only where supported by the model/system specification.

---

## 6. What Is Explicitly NOT Required Now

Do NOT implement these in the Round II prototype unless specifically requested later:

- QR scanning
- QR-based cow identification
- Collar BLE integration
- Cloud infrastructure
- Authentication
- User management
- Cooperative dashboard
- Veterinary dashboard
- GIS
- Multi-farm management
- Push notifications
- Production telemetry synchronization
- Advanced personalized baselines
- Production-grade forecasting
- New ML model training
- Replacing the existing ML model
- Complex analytics dashboards

---

## 7. Why Collar Data Is Imported From a File

The collar is conceptually a longitudinal telemetry collector.

For the prototype, its historical data is imported from a CSV or JSON file instead of connecting the collar through BLE.

This allows the prototype to demonstrate longitudinal collar data without spending development time on collar BLE integration.

The architecture MUST still use an abstraction so that a real BLE collar implementation can replace the file implementation later.

---

## 8. Why QR Is Removed

QR identification is intentionally excluded from the current prototype.

The imported collar file already contains the cow identifier.

Therefore:

    Collar File
        |
        +-- cow_id = COW-104

is sufficient to associate the history with the cow.

QR can be added later without redesigning the analysis pipeline.

---

## 9. Core Architectural Principle

Hardware communication MUST remain separate from business logic.

The application should follow:

    Hardware
       |
       v
    BLE Provider
       |
       v
    Domain Model
       |
       v
    Analysis/API Layer
       |
       v
    FastAPI
       |
       v
    ML

The rest of the application must not directly depend on BLE characteristics or ESP32 packet formats.

---

## 10. Provider Abstraction

Use interfaces/abstract classes for hardware data sources.

Example:

    CollarDataProvider
       |
       +-- FileCollarDataProvider
       |
       +-- BleCollarDataProvider (future)

and:

    MilkDataProvider
       |
       +-- MockMilkTester
       |
       +-- BleMilkTester

The mock provider and real provider MUST expose the same domain model.

This allows development and testing to proceed before hardware integration is complete.

---

## 11. Current Development Strategy

Development follows:

    TEST -> VERIFY -> PROGRESS

First implement the entire software pipeline with a mock milk tester:

    MockMilkTester
         |
         v
    Flutter
         |
         v
    FastAPI
         |
         v
    Existing ML model
         |
         v
    Prediction
         |
         v
    Flutter result screen

Once this works, replace only:

    MockMilkTester

with:

    BleMilkTester

The rest of the application should remain unchanged.

---

## 12. Important ML Constraint

The current ML model must NOT be replaced or silently modified.

The application must use the actual feature contract of the existing model.

Before implementing inference, inspect the existing model/training/inference code and document:

- model type
- model file
- feature names
- feature order
- preprocessing
- encoding
- scaling
- expected input shape
- output format
- class meanings

Do not guess these values.

---

## 13. Scientific Claim Constraint

The current prototype must not claim that the existing ML model provides clinically validated mastitis diagnosis or a scientifically validated 14-day forecast unless the actual trained model and evaluation support that claim.

The UI should accurately describe what the current model actually predicts.

The final product may later use a more sophisticated longitudinal forecasting model.

---

## 14. Design Goal

The Round II application should be:

- Small
- Stable
- Testable
- Modular
- Hardware-independent at the business-logic level
- Easy to replace mock hardware with real hardware
- Easy to extend toward the final Gau-Prahari product

Do not over-engineer features that are not required for the prototype.