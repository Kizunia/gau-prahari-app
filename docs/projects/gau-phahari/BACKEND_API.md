# Gau-Prahari — Backend API Specification

## 1. Purpose

FastAPI acts as the inference backend.

The mobile application sends normalized data to FastAPI.

FastAPI:

1. Validates the request.
2. Prepares model input.
3. Runs the existing ML model.
4. Produces a prediction.
5. Returns a structured response.

---

# 2. Architecture

    Flutter
       |
       | HTTPS
       v
    FastAPI
       |
       v
    Validation
       |
       v
    Feature Preparation
       |
       v
    Existing ML Model
       |
       v
    Prediction
       |
       v
    JSON Response
       |
       v
    Flutter

---

# 3. Endpoint

Recommended endpoint:

    POST /api/v1/analysis/predict

The final endpoint should follow the existing FastAPI project's routing conventions if they already exist.

Do not create duplicate routing structures.

---

# 4. Request

Conceptual request:

    {
      "cow_id": "COW-104",
      "collar_data": [
        {
          "timestamp": "...",
          "activity": 72,
          "skin_temperature": 37.1,
          "ambient_temperature": 29.2,
          "humidity": 61.0,
          "thi": 77.3
        }
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

The actual request schema must be aligned with the current model.

---

# 5. Pydantic Models

Use Pydantic request/response models.

Conceptually:

    class MilkData(BaseModel):
        milk_temperature: float
        ph: float
        conductivity: float
        scc: int
        fat: float
        snf: float

    class AnalysisRequest(BaseModel):
        cow_id: str
        collar_data: list
        milk_data: MilkData

The collar_data model should be strongly typed once its actual schema is known.

Avoid using untyped dictionaries throughout the application.

---

# 6. Model Loading

The ML model should be loaded once when the FastAPI application starts.

Do NOT load the model for every request.

Recommended lifecycle:

    FastAPI startup
          |
          v
    Load model
          |
          v
    Keep model in memory
          |
          v
    Requests use loaded model

---

# 7. Inference Separation

Keep model inference separate from HTTP routing.

Recommended:

    api/
       analysis.py

    services/
       inference_service.py

    ml/
       model_loader.py
       predictor.py

The exact structure should follow the existing backend codebase.

Do not restructure the backend unnecessarily if an established architecture already exists.

---

# 8. Inference Process

Conceptual:

    request
      |
      v
    Validate
      |
      v
    Extract model features
      |
      v
    Apply training-time preprocessing
      |
      v
    model.predict(...)
      |
      v
    Convert output
      |
      v
    Response model

---

# 9. Model Contract

The exact feature list MUST be obtained from the existing trained model.

Do not assume the model uses:

- collar data
- SCC
- milk temperature
- pH
- conductivity
- fat
- SNF

unless confirmed by the existing training code/model.

The current dataset is known to contain:

    Cow_ID
    Day
    Milk_Temperature
    Milk_pH
    Milk_Conductivity
    Somatic_Cell_Count
    Milk_Yield
    Clotting
    class1

But the final model input must be determined from the actual implementation.

---

# 10. Response

Conceptual:

    {
      "cow_id": "COW-104",
      "prediction": 1,
      "risk_level": "HIGH"
    }

If the model provides probability:

    {
      "cow_id": "COW-104",
      "prediction": 1,
      "probability": 0.82,
      "risk_level": "HIGH"
    }

Do not fabricate probability values.

---

# 11. HTTP Status Codes

Recommended:

    200
    Successful prediction

    400
    Invalid request

    422
    Pydantic validation failure

    500
    Inference/server error

---

# 12. Backend Must Not

The backend must not:

- modify the trained model automatically
- retrain the model during a request
- fabricate measurements
- fabricate model explanations
- silently reorder features
- silently change preprocessing
- claim clinical diagnosis
- claim validated forecasting that the model does not support

---

# 13. Local Development

During prototype development, Flutter may connect to a local FastAPI server.

The mobile application should use a configurable API base URL.

Do not hard-code production URLs throughout the application.

Example conceptual configuration:

    API_BASE_URL

---

# 14. Testing

Backend tests should verify:

1. Valid request accepted.
2. Invalid request rejected.
3. Model loads.
4. Feature preparation works.
5. Model inference works.
6. Response schema is correct.
7. Model errors do not crash the server.