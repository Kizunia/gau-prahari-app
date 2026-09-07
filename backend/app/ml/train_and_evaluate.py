import os
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import StratifiedKFold, cross_validate, train_test_split, GridSearchCV
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, ExtraTreesClassifier
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    roc_auc_score,
    confusion_matrix,
    classification_report,
)

DATA_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "data", "mastitis_dataset.csv")
MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "models")
MODEL_PATH = os.path.join(MODEL_DIR, "mastitis_classifier.joblib")

CORE_FEATURES = [
    "Milk_Temperature",
    "Milk_pH",
    "Milk_Conductivity",
    "Somatic_Cell_Count",
]

def load_data(filepath=DATA_PATH):
    df = pd.read_csv(filepath)
    # Somatic_Cell_Count is in thousands in dataset (e.g., 148 = 148,000 cells/mL)
    X = df[CORE_FEATURES].copy()
    y = df["class1"].values
    return df, X, y

def train_and_evaluate():
    df, X, y = load_data()
    print("=" * 60)
    print("GAU-PRAHARI BOVINE MASTITIS ML TRAINING & EVALUATION")
    print("=" * 60)
    print(f"Total Samples: {len(df)}")
    print(f"Healthy (Class 0): {np.sum(y == 0)} ({np.sum(y == 0)/len(y)*100:.1f}%)")
    print(f"Mastitis (Class 1): {np.sum(y == 1)} ({np.sum(y == 1)/len(y)*100:.1f}%)")
    print(f"Features: {CORE_FEATURES}\n")

    # 1. Stratified 5-Fold Cross Validation benchmark
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    models = {
        "RandomForest": RandomForestClassifier(n_estimators=150, max_depth=6, random_state=42),
        "ExtraTrees": ExtraTreesClassifier(n_estimators=150, max_depth=6, random_state=42),
        "GradientBoosting": GradientBoostingClassifier(n_estimators=100, max_depth=4, random_state=42),
    }

    print("--- 5-Fold Stratified Cross-Validation Benchmark ---")
    for name, clf in models.items():
        scores = cross_validate(clf, X, y, cv=cv, scoring=["accuracy", "precision", "recall", "f1", "roc_auc"])
        print(f"{name:18s} | Acc: {scores['test_accuracy'].mean():.4f} (+/- {scores['test_accuracy'].std():.4f}) | Prec: {scores['test_precision'].mean():.4f} | Rec: {scores['test_recall'].mean():.4f} | F1: {scores['test_f1'].mean():.4f} | AUC: {scores['test_roc_auc'].mean():.4f}")

    # 2. Hyperparameter Grid Search on Random Forest for optimal generalization
    param_grid = {
        "n_estimators": [100, 150, 200],
        "max_depth": [4, 6, 8, None],
        "min_samples_split": [2, 5],
        "min_samples_leaf": [1, 2],
        "class_weight": ["balanced", None],
    }

    grid = GridSearchCV(
        RandomForestClassifier(random_state=42),
        param_grid,
        cv=cv,
        scoring="accuracy",
        n_jobs=-1,
    )
    grid.fit(X, y)
    best_clf = grid.best_estimator_
    print(f"\nOptimal Random Forest Hyperparameters: {grid.best_params_}")
    print(f"Best CV Accuracy: {grid.best_score_:.4f}")

    # 3. Train/Test Hold-out Evaluation (80% train / 20% test)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.20, random_state=42, stratify=y)
    best_clf.fit(X_train, y_train)

    y_pred = best_clf.predict(X_test)
    y_prob = best_clf.predict_proba(X_test)[:, 1]

    acc = accuracy_score(y_test, y_pred)
    prec = precision_score(y_test, y_pred)
    rec = recall_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_prob)
    cm = confusion_matrix(y_test, y_pred)

    print("\n--- Hold-out Test Set Performance (N=160) ---")
    print(f"Accuracy  : {acc * 100:.2f}%")
    print(f"Precision : {prec * 100:.2f}%")
    print(f"Recall    : {rec * 100:.2f}%")
    print(f"F1-Score  : {f1 * 100:.2f}%")
    print(f"ROC-AUC   : {auc:.4f}")
    print("\nConfusion Matrix:")
    print(f"  TN: {cm[0,0]} | FP: {cm[0,1]}")
    print(f"  FN: {cm[1,0]} | TP: {cm[1,1]}")
    print("\nClassification Report:\n", classification_report(y_test, y_pred, target_names=["Healthy (0)", "Mastitis (1)"]))

    print("Feature Importances:")
    for feat, imp in sorted(zip(CORE_FEATURES, best_clf.feature_importances_), key=lambda x: x[1], reverse=True):
        print(f"  {feat:22s}: {imp * 100:.2f}%")

    # 4. Fit on entire dataset for production deployment and save
    best_clf.fit(X, y)
    os.makedirs(MODEL_DIR, exist_ok=True)
    joblib.dump(best_clf, MODEL_PATH)
    print(f"\nModel successfully trained and saved to: {os.path.abspath(MODEL_PATH)}")

    return best_clf

if __name__ == "__main__":
    train_and_evaluate()
