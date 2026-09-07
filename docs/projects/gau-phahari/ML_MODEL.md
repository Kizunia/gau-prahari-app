# Gau-Prahari — ML Model Specification

## 1. Purpose

This document defines how the existing trained ML model must be integrated into Gau-Prahari.

The existing model MUST be preserved for the current prototype.

Do not replace it with another algorithm unless explicitly requested.

---

# 2. Current Known Dataset

The current model was trained using the Kaggle dataset:

    Cow Mastitis (From milk)

Dataset columns known from the training dataset:

    Cow_ID
    Day
    Milk_Temperature
    Milk_pH
    Milk_Conductivity
    Somatic_Cell_Count
    Milk_Yield
    Clotting
    class1

Example record:

    C0001,7,35.38,6.49,4.68,148,17.3,0,0

---

# 3. Important Limitation

The existence of the dataset does NOT by itself establish that:

- the model is a 14-day forecasting model
- the model performs clinical mastitis diagnosis
- the model is clinically validated
- the model uses collar telemetry
- the model produces calibrated probabilities
- the model provides feature explanations

These claims must only be made if supported by the actual training and evaluation code.

---

# 4. Existing Model

The exact model implementation must be inspected before finalizing this document.

Required information:

    Model algorithm:
    <TO BE VERIFIED>

    Model file:
    <TO BE VERIFIED>

    Input features:
    <TO BE VERIFIED>

    Feature order:
    <TO BE VERIFIED>

    Preprocessing:
    <TO BE VERIFIED>

    Scaling:
    <TO BE VERIFIED>

    Encoding:
    <TO BE VERIFIED>

    Output:
    <TO BE VERIFIED>

    Class mapping:
    <TO BE VERIFIED>

---

# 5. Inference Contract

The backend must reproduce the exact inference process used during training.

If training performed:

    scaling

then inference must use the same scaler.

If training performed:

    categorical encoding

then inference must use the same encoding.

If training expects a specific feature order:

    inference MUST preserve that order.

---

# 6. Feature Leakage Check

The dataset contains:

    Somatic_Cell_Count

and:

    class1

The relationship between SCC and class1 must be inspected.

Before making strong claims about model performance, determine whether the target label is derived directly or indirectly from one of the input features.

If target leakage exists, it must be documented.

---

# 7. Current Prototype Integration

The ML model should be wrapped behind an inference service.

Conceptual:

    class Predictor:
        def predict(...)
            ...

Flutter must never know:

- model filename
- model algorithm
- preprocessing
- feature order

Flutter only receives the backend response.

---

# 8. Example Inference Pipeline

Conceptually:

    API Request
         |
         v
    Extract model features
         |
         v
    Preprocessing
         |
         v
    Existing model
         |
         v
    Prediction
         |
         v
    Response DTO

---

# 9. Probability

Only expose probability if the model actually supports probability prediction.

For example:

    predict_proba()

If probability is unavailable, return the class prediction only.

Never convert a class label such as:

    1

into:

    100%

---

# 10. Risk Levels

If the model is binary:

    class 0
    class 1

the exact meaning of these classes MUST be verified from the training code/dataset.

Only after verification should the backend map them to labels such as:

    LOW
    HIGH

---

# 11. Explainability

Potential future implementation:

    SHAP
    feature contribution
    permutation importance

However, explainability MUST NOT be fabricated.

For the current prototype, display feature drivers only if the inference implementation actually calculates them.

---

# 12. Longitudinal Collar Data

The final Gau-Prahari product is intended to use longitudinal collar data.

However, if the current trained model is milk-only, collar telemetry must NOT be inserted into the model input simply because it exists in the product.

Instead:

    Collar Data
        |
        v
    Stored/available for future model
        |
        X
        |
    Current ML model

until a multimodal model has actually been trained.

---

# 13. Future ML

A future production model may combine:

    Milk Features
    +
    Collar Behaviour
    +
    Temperature
    +
    THI
    +
    Longitudinal Baselines
    +
    Historical Trends

That model should be trained and evaluated separately.

It should not be mixed into the Round II implementation unless explicitly requested.

---

# 14. Model Validation Requirements

Before claiming model performance, document:

- dataset size
- train/test split
- validation methodology
- class distribution
- accuracy
- precision
- recall
- F1
- ROC-AUC if applicable
- confusion matrix
- leakage analysis

Do not report metrics that have not actually been measured.

---

# 15. Required Agent Action

Before implementing ML integration:

1. Search the repository for the model.
2. Find the training code.
3. Find preprocessing code.
4. Find inference code.
5. Determine exact input features.
6. Determine exact feature order.
7. Determine output classes.
8. Determine whether probability is available.
9. Determine model serialization format.
10. Update this document with verified values.

Do not guess.