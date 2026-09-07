# Gau-Prahari — Implementation Plan

## 1. Development Philosophy

Development must follow:

    TEST -> VERIFY -> PROGRESS

Do not build the complete system at once.

Every phase must produce a working/testable state.

---

# 2. Phase 0 — Repository Inspection

Before modifying code:

1. Inspect the Flutter project.
2. Identify current architecture.
3. Identify state management.
4. Identify routing.
5. Identify existing BLE code.
6. Identify existing HTTP/API code.
7. Identify existing models.
8. Identify backend integration.
9. Identify ML files.
10. Identify existing tests.

Do not rewrite existing architecture without a reason.

---

# 3. Phase 1 — Domain Models

Create or verify:

    Cow
    CollarTelemetry
    CollarHistory
    MilkMeasurement
    AnalysisRequest
    AnalysisResult

Test:

    Model construction
    Serialization
    Deserialization
    Validation

---

# 4. Phase 2 — Milk Provider Abstraction

Create:

    MilkDataProvider

Then implement:

    MockMilkTester

The mock provider returns a valid MilkMeasurement.

Test:

    MockMilkTester
        |
        v
    MilkMeasurement

The UI should be able to display the measurement.

---

# 5. Phase 3 — Collar File Provider

Create:

    CollarDataProvider

Implement:

    FileCollarDataProvider

Responsibilities:

- Open file picker
- Read file
- Parse CSV/JSON
- Validate data
- Convert to CollarHistory

Test with:

- valid CSV
- valid JSON
- malformed file
- missing fields
- invalid numbers
- cow ID mismatch

---

# 6. Phase 4 — Flutter -> FastAPI

Implement the API client.

Flow:

    Flutter
       |
       | HTTPS POST
       v
    FastAPI

Test using a known valid request.

Do not connect BLE yet.

---

# 7. Phase 5 — FastAPI -> ML

Integrate the existing ML model.

Flow:

    API request
       |
       v
    Feature preparation
       |
       v
    Existing model
       |
       v
    Prediction
       |
       v
    JSON response

Test independently of Flutter.

---

# 8. Phase 6 — Full Mock Pipeline

At this point the complete software pipeline must work:

    Collar File
         +
    Mock Milk Tester
         |
         v
    Flutter
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

This is the first major milestone.

Do not proceed to real BLE until this works.

---

# 9. Phase 7 — BLE Discovery

Implement:

    BleMilkTester

Start with:

1. Scan
2. Discover device
3. Connect
4. Discover services
5. Find measurement characteristic

Do not integrate the backend yet.

Test:

    ESP32
      |
      v
    BLE
      |
      v
    Flutter

---

# 10. Phase 8 — BLE Payload Parsing

Receive the ESP32 measurement.

Convert:

    raw BLE payload
          |
          v
    MilkMeasurement

Test all fields.

Example:

    temperature
    pH
    conductivity
    SCC
    fat
    SNF

The result must be identical in structure to MockMilkTester output.

---

# 11. Phase 9 — Real Hardware Pipeline

Replace:

    MockMilkTester

with:

    BleMilkTester

WITHOUT changing:

- UI
- API client
- analysis service
- FastAPI
- ML integration
- result screen

The only changed layer should be the data provider.

---

# 12. Phase 10 — End-to-End Test

Final prototype test:

    Import Collar History
          |
          v
    Select Cow
          |
          v
    Connect Milk Tester
          |
          v
    Receive Real Measurement
          |
          v
    Build Analysis Request
          |
          v
    FastAPI
          |
          v
    ML Model
          |
          v
    Prediction
          |
          v
    Flutter Result

---

# 13. Testing Checklist

## Flutter

- [ ] App launches
- [ ] Cow selection works
- [ ] File picker works
- [ ] CSV parser works
- [ ] JSON parser works
- [ ] Invalid files handled
- [ ] Mock milk tester works
- [ ] API client works
- [ ] Result screen works

## BLE

- [ ] Bluetooth permission handled
- [ ] Device discovery works
- [ ] Connection works
- [ ] Service discovery works
- [ ] Characteristic found
- [ ] Notification received
- [ ] Payload parsed
- [ ] Disconnect handled

## Backend

- [ ] Server starts
- [ ] Endpoint responds
- [ ] Request validation works
- [ ] Model loads
- [ ] Feature preparation works
- [ ] Prediction works
- [ ] Response schema works
- [ ] Errors handled

## ML

- [ ] Correct model file
- [ ] Correct preprocessing
- [ ] Correct feature order
- [ ] Correct class mapping
- [ ] Prediction verified

---

# 14. Priority Levels

## P0 — Must Work

- Flutter app
- Cow selection
- Collar file import
- Milk provider abstraction
- Mock milk tester
- FastAPI
- Existing ML model
- Prediction response
- Result screen
- Real milk tester BLE

---

## P1 — Useful If Time Allows

- Collar history preview
- Simple telemetry chart
- Milk measurement cards
- Better loading states
- BLE connection status
- Risk factor visualization
- Demo dataset selector
- Basic history screen

---

## P2 — Future

- Collar BLE
- QR identification
- Cloud synchronization
- Authentication
- Cooperative dashboard
- Veterinary dashboard
- GIS
- Personalized baselines
- Multimodal ML
- Advanced forecasting
- Notifications
- Production deployment

---

# 15. Rules for the Coding Agent

The coding agent MUST follow these rules.

### Rule 1

Do not implement features that are explicitly out of scope.

### Rule 2

Do not replace the existing ML model.

### Rule 3

Do not invent ML inputs or outputs.

### Rule 4

Do not invent BLE UUIDs without clearly marking them as temporary or obtaining them from the firmware.

### Rule 5

Do not put BLE logic inside UI widgets.

### Rule 6

Do not put HTTP calls directly inside UI widgets.

### Rule 7

Do not put ML preprocessing inside Flutter.

### Rule 8

Do not hard-code production data.

### Rule 9

Use abstractions where hardware implementations may change.

### Rule 10

Every implementation phase must be independently testable.

### Rule 11

Prefer the smallest implementation that satisfies the current requirement.

### Rule 12

Do not rewrite working code merely for stylistic reasons.

---

# 16. Definition of Done

The Round II prototype is complete when:

    Collar File
        |
        v
    Flutter
        ^
        |
    Real Milk Tester BLE
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

works end-to-end on an Android device.

The prototype must be demonstrable without QR scanning or collar BLE.