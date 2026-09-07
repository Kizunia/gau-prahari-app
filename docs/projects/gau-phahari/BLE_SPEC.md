
---

# 4. `BLE_SPEC.md`

```md
# Gau-Prahari — Milk Tester BLE Specification

## 1. Purpose

Define the BLE contract between:

- ESP32 Milk Tester
- Android Flutter application

The mobile application is the BLE central/client.

The ESP32 is the BLE peripheral/server.

---

# 2. Scope

This specification covers only the milk tester.

The collar BLE implementation is NOT part of the current Round II prototype.

---

# 3. BLE Architecture

    ESP32 Milk Tester
          |
          | BLE / GATT
          |
          v
    Android Phone
          |
          v
       Flutter
          |
          v
    MilkMeasurement

---

# 4. Device Discovery

The application should scan for the milk tester.

The final implementation requires a defined device identifier.

Recommended:

    Device Name:
    GAU-PRAHARI-MILK

The exact name may be changed according to the ESP32 firmware.

Do not hard-code assumptions if the firmware uses another name.

---

# 5. GATT Service

The milk tester should expose a dedicated custom BLE service.

Required information:

    Service UUID:
    <TO BE DEFINED>

The UUID must be shared between firmware and Flutter.

---

# 6. Measurement Characteristic

The tester should expose a measurement characteristic.

Required information:

    Measurement Characteristic UUID:
    <TO BE DEFINED>

Preferred behavior:

    ESP32 -> notify -> Flutter

The tester can send a measurement when a complete sample is available.

---

# 7. Measurement Payload

Recommended payload format for the prototype:

    JSON

Example:

    {
      "cow_id": "COW-104",
      "milk_temperature": 35.8,
      "ph": 6.72,
      "conductivity": 6.18,
      "scc": 420000,
      "fat": 4.1,
      "snf": 8.6
    }

If JSON exceeds BLE characteristic limits, implement appropriate BLE chunking or use a compact binary/encoded format.

For the first implementation, keep the protocol as simple as possible.

---

# 8. Important Rule

The BLE layer must convert the hardware payload into:

    MilkMeasurement

Example:

    BLE bytes
       |
       v
    Decode payload
       |
       v
    Validate fields
       |
       v
    MilkMeasurement

The rest of Flutter must not know about:

- characteristic UUIDs
- BLE bytes
- BLE packet structure
- notification streams

---

# 9. Connection Lifecycle

The BLE provider should support:

    scan()
    connect()
    discoverServices()
    subscribeToMeasurement()
    receiveMeasurement()
    disconnect()

Conceptual lifecycle:

    Disconnected
        |
        v
    Scanning
        |
        v
    Device Found
        |
        v
    Connecting
        |
        v
    Connected
        |
        v
    Discovering Services
        |
        v
    Ready
        |
        v
    Waiting For Measurement
        |
        v
    Measurement Received
        |
        v
    Ready / Disconnect

---

# 10. Error Handling

Handle:

- Bluetooth disabled
- Permission denied
- Device unavailable
- Connection timeout
- Service not found
- Characteristic not found
- Notification subscription failure
- Malformed payload
- Missing fields
- Invalid values
- Unexpected disconnect

Do not crash the application.

---

# 11. Measurement Completion

The application must know when a complete milk measurement has been received.

Recommended:

    ESP32 sends one complete measurement notification.

Flutter parses it and emits:

    MilkMeasurement

The exact protocol may later be expanded with:

    measurement_start
    measurement_progress
    measurement_complete
    error

but this is not necessary for the first prototype.

---

# 12. Mock Implementation

The application MUST support:

    MockMilkTester

with exactly the same public interface as:

    BleMilkTester

Example:

    abstract class MilkDataProvider {
      Future<MilkMeasurement> getMeasurement();
    }

Mock:

    class MockMilkTester implements MilkDataProvider {
      @override
      Future<MilkMeasurement> getMeasurement() async {
        return MilkMeasurement(
          cowId: "COW-104",
          milkTemperature: 35.8,
          ph: 6.72,
          conductivity: 6.18,
          scc: 420000,
          fat: 4.1,
          snf: 8.6,
        );
      }
    }

Real:

    class BleMilkTester implements MilkDataProvider {
      ...
    }

---

# 13. No Business Logic in BLE

BLE implementation MUST NOT:

- call FastAPI
- run ML
- determine mastitis risk
- navigate screens
- display UI
- calculate clinical diagnosis

Its only responsibility is:

    BLE hardware
        ->
    MilkMeasurement

---

# 14. Future Collar BLE

The collar can later use a separate:

    CollarDataProvider

with:

    FileCollarDataProvider
    BleCollarDataProvider

The milk tester BLE implementation must not be coupled to collar BLE implementation.