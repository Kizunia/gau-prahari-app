# Gau-Prahari — Application Requirements

## 1. Objective

Build a minimal but functional Android application demonstrating the complete Gau-Prahari analysis pipeline.

The application must allow a user to:

1. Select a cow.
2. Import historical collar data.
3. Connect to the milk tester.
4. Receive milk measurements.
5. Submit data for analysis.
6. Receive the ML result.
7. Display the result clearly.

---

# 2. Prototype Flow

The primary flow is:

    Home
      |
      v
    Select Cow
      |
      v
    Import Collar History
      |
      v
    Connect Milk Tester
      |
      v
    Receive Milk Measurement
      |
      v
    Analyze
      |
      v
    Result

---

# 3. Screen Requirements

## 3.1 Home / Cow Selection

Purpose:

Allow the user to select an animal without QR scanning.

Required:

- Cow list
- Cow ID
- Selected cow state
- Continue button

Example:

    Select Cow

    COW-101
    COW-102
    COW-104

    [Continue]

The list may initially be populated from imported data or local demo data.

No QR scanner is required.

---

# 4. Collar History Import

The screen must provide:

    Import Collar History

The user should be able to select:

- CSV
- JSON

from the Android file manager.

After import:

- Parse the file.
- Validate the structure.
- Extract cow ID.
- Store the telemetry in memory/local application state.
- Display a success state.

Example:

    Collar History
    COW-104

    14 days imported

    Activity       Available
    Skin Temp      Available
    Ambient Temp   Available
    Humidity       Available
    THI             Available

    [Continue]

---

# 5. Collar Import Requirements

The import layer must:

1. Open Android file picker.
2. Read the selected file.
3. Detect CSV/JSON.
4. Parse data.
5. Validate required fields.
6. Convert values to typed Dart models.
7. Associate data with cow_id.
8. Return a domain-level collar history object.

The UI must not parse CSV/JSON directly.

---

# 6. Milk Tester

The application must support the real milk tester through BLE.

The application should expose:

    Connect Milk Tester

The UI should display states:

- Searching
- Connecting
- Connected
- Waiting for measurement
- Measurement received
- Disconnected
- Error

---

# 7. Mock Milk Tester

Before BLE implementation is complete, a mock implementation MUST be used.

Example:

    MockMilkTester

It must implement the same interface as:

    BleMilkTester

Example abstraction:

    abstract class MilkDataProvider {
        Future<MilkMeasurement> getMeasurement();
    }

Mock implementation:

    MockMilkTester implements MilkDataProvider

Real implementation:

    BleMilkTester implements MilkDataProvider

The UI and analysis layers must depend only on MilkDataProvider.

---

# 8. Milk Measurement Screen

Once a measurement is received, display:

- Milk temperature
- pH
- Conductivity
- SCC
- Fat %
- SNF %

Example:

    Milk Measurement

    Temperature     35.8 °C
    pH               6.72
    Conductivity     6.18 mS/cm
    SCC               420000
    Fat               4.1 %
    SNF               8.6 %

    [Analyze]

Values must come from the actual provider.

Do not hard-code values in the production flow.

---

# 9. Analysis

When the user presses Analyze:

1. Validate selected cow.
2. Validate collar data.
3. Validate milk data.
4. Build the API request.
5. Send HTTPS request to FastAPI.
6. Wait for response.
7. Parse response.
8. Navigate to result screen.

Show a loading state while inference is running.

---

# 10. Result Screen

The result screen must clearly display:

- Risk classification
- Model score/probability if provided
- Important model factors if actually available
- Recommended action if defined by the system

Example:

    Mastitis Risk

    HIGH RISK

    Risk Score
    0.82

    Key Factors
    ↑ Milk conductivity
    ↑ SCC
    ...

    Recommended Action

    Perform confirmatory mastitis testing
    and inspect the animal.

The exact score and factors MUST come from the backend/model.

Do not invent them in Flutter.

---

# 11. Error Handling

The application must handle:

### File errors

- Unsupported file
- Invalid CSV
- Invalid JSON
- Missing fields
- Invalid numeric values
- Cow ID mismatch

### BLE errors

- Bluetooth disabled
- Permission denied
- Device not found
- Connection timeout
- Disconnection
- Invalid packet
- Invalid measurement

### Backend errors

- Network unavailable
- Timeout
- HTTP 4xx
- HTTP 5xx
- Invalid response

The UI must show a useful error message instead of crashing.

---

# 12. Architecture Requirements

Use separation between:

### Presentation

Flutter screens/widgets.

### Domain

Models and provider interfaces.

### Data

File parser, BLE implementation, HTTP client.

### Backend

FastAPI API.

### ML

Existing trained model.

The UI must not contain:

- BLE packet parsing
- HTTP request construction
- ML preprocessing
- CSV parsing
- model logic

---

# 13. State Management

Use the project's existing state-management approach if one already exists.

Do not introduce a new state-management framework without inspecting the current codebase first.

---

# 14. Persistence

Persistent storage is NOT required for the first working prototype.

In-memory state is acceptable.

If the existing application already has a local database/storage layer, do not remove it.

---

# 15. Navigation

Navigation should be simple.

Recommended:

    Home
      |
    Cow Selection
      |
    Collar Import
      |
    Milk Tester
      |
    Measurement
      |
    Analysis
      |
    Result

Do not build a complex navigation architecture for the prototype.

---

# 16. Prototype Acceptance Criteria

The prototype is considered working when:

1. Application launches.
2. Cow can be selected.
3. Collar file can be imported.
4. Collar data is parsed correctly.
5. Mock milk tester returns a MilkMeasurement.
6. Flutter can call FastAPI.
7. FastAPI runs the existing ML model.
8. FastAPI returns prediction JSON.
9. Flutter displays prediction.
10. Real milk tester can replace mock provider.
11. Real milk measurement reaches Flutter.
12. Real measurement reaches FastAPI.
13. Result is displayed without changing the analysis architecture.