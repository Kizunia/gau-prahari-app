# Gau-Prahari — Data Contract

## 1. Purpose

This document defines the internal data models exchanged between:

- Collar data source
- Flutter application
- Milk tester
- FastAPI backend
- ML inference layer

The domain models must remain independent from hardware packet formats.

---

# 2. Cow Identity

Every dataset must contain:

    cow_id

Example:

    COW-104

The cow ID is used to associate collar history and milk measurements.

QR scanning is not required for the current prototype.

---

# 3. Collar Telemetry

The collar represents longitudinal data.

A telemetry record should conceptually contain:

    {
      "cow_id": "COW-104",
      "timestamp": "...",
      "activity": ...,
      "skin_temperature": ...,
      "ambient_temperature": ...,
      "humidity": ...,
      "thi": ...
    }

The exact fields must match the actual imported dataset.

Do not silently invent fields during implementation.

---

# 4. CollarHistory

Recommended conceptual model:

    CollarHistory {
        cowId
        records
    }

Where:

    records = List<CollarTelemetry>

Example:

    {
      "cow_id": "COW-104",
      "records": [
        {
          "timestamp": "2026-09-01T08:00:00",
          "activity": 72,
          "skin_temperature": 37.1,
          "ambient_temperature": 29.2,
          "humidity": 61.0,
          "thi": 77.3
        }
      ]
    }

The actual field names must follow the imported file contract.

---

# 5. MilkMeasurement

Internal Flutter model:

    class MilkMeasurement {
      final String cowId;
      final double milkTemperature;
      final double ph;
      final double conductivity;
      final int scc;
      final double fat;
      final double snf;
    }

Conceptual JSON:

    {
      "cow_id": "COW-104",
      "milk_temperature": 35.8,
      "ph": 6.72,
      "conductivity": 6.18,
      "scc": 420000,
      "fat": 4.1,
      "snf": 8.6
    }

---

# 6. BLE Payload vs Domain Model

The BLE packet format is an implementation detail.

For example, the ESP32 may transmit:

    raw bytes

or:

    JSON

or:

    delimited text

Flutter must convert the raw BLE payload into:

    MilkMeasurement

Only MilkMeasurement should be passed to the rest of the application.

---

# 7. Combined Analysis Request

Conceptual request:

    {
      "cow_id": "COW-104",
      "collar_data": [
        ...
      ],
      "milk_data": {
        "milk_temperature": 35.8,
        "ph": 6.72,
        "conductivity": 6.18,
        "scc": 420000,
        "fat": 4.1,
        "snf": 8.6
      }
    }

The exact backend request must be reconciled with the existing ML model.

If the current model does not use collar features, collar_data should not be artificially inserted into the model feature vector.

---

# 8. Model Input Contract

The ML model's feature vector MUST be determined from the existing training/inference code.

Do not assume:

- feature order
- preprocessing
- scaling
- encoding
- normalization
- categorical handling

The backend must reproduce the training-time preprocessing exactly.

---

# 9. Prediction Response

Conceptual response:

    {
      "cow_id": "COW-104",
      "prediction": 1,
      "probability": 0.82,
      "risk_level": "HIGH"
    }

However, the actual response must match the existing model.

If the model does not output a probability, do not fabricate one.

If the model only returns a binary class, do not claim that it is a calibrated risk score.

---

# 10. Explanation Contract

Explanations must only be displayed if they are supported by the inference pipeline.

Possible future response:

    {
      "prediction": 1,
      "probability": 0.82,
      "risk_level": "HIGH",
      "factors": [
        {
          "feature": "Milk_Conductivity",
          "direction": "high"
        }
      ]
    }

This must not be implemented unless the backend actually calculates these factors.

---

# 11. Validation

Required validation:

### cow_id

Must not be empty.

### milk_temperature

Must be numeric and within a physically reasonable range.

### pH

Must be numeric.

### conductivity

Must be numeric.

### SCC

Must be numeric and non-negative.

### fat

Must be numeric and non-negative.

### SNF

Must be numeric and non-negative.

Validation limits should be centralized and documented rather than duplicated throughout the UI.

---

# 12. Cow Consistency

The cow ID from collar history and the selected cow must match.

If milk data contains cow_id, it must also match.

Example:

    Selected cow: COW-104
    Collar data:  COW-104
    Milk data:    COW-104

Valid.

Example:

    Selected cow: COW-104
    Collar data:  COW-104
    Milk data:    COW-109

Invalid.

---

# 13. Data Flow

    File
      |
      v
    CollarTelemetry
      |
      v
    CollarHistory
      |
      |
      +----------------+
                       |
    BLE               |
      |                |
      v                |
    MilkMeasurement    |
      |                |
      +-------+--------+
              |
              v
       Analysis Request
              |
              v
           FastAPI
              |
              v
        ML preprocessing
              |
              v
          ML model
              |
              v
        Prediction