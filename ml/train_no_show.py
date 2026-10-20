"""
Train No-Show Prediction Model with Time-Based Split and Calibration Evaluation.
Exports weights to JSON for production TypeScript scoring engine.
"""

import json
import math
import os
import csv
from datetime import datetime

def load_data(csv_path):
    if not os.path.exists(csv_path):
        import generate_synthetic_data
        generate_synthetic_data.main()

    records = []
    with open(csv_path, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            records.append(r)
    return records

def extract_features(r):
    lead_time = float(r["lead_time_days"])
    dow = float(r["day_of_week"])
    hour = float(r["appointment_hour"])
    past_misses = float(r["past_missed_count"])
    attendance_rate = float(r["past_attendance_rate"])
    plan_stage = float(r["treatment_plan_stage"])
    
    is_unconfirmed = 1.0 if r["reminder_response"] == "unconfirmed" else 0.0
    is_confirmed = 1.0 if r["reminder_response"] == "confirmed" else 0.0
    is_whatsapp = 1.0 if r["channel"] == "whatsapp" else 0.0
    is_weekend = 1.0 if dow >= 5 else 0.0
    is_late_hour = 1.0 if hour >= 18 or hour <= 9 else 0.0

    # Feature vector
    return [
        1.0, # Intercept / bias
        min(lead_time / 30.0, 1.0),
        min(past_misses / 4.0, 1.0),
        1.0 - attendance_rate,
        is_unconfirmed,
        is_confirmed,
        is_whatsapp,
        is_weekend,
        is_late_hour,
        min(plan_stage / 4.0, 1.0)
    ]

def sigmoid(z):
    return 1.0 / (1.0 + math.exp(-max(min(z, 20.0), -20.0)))

def train_logistic_model(X_train, y_train, epochs=200, lr=0.1):
    num_features = len(X_train[0])
    weights = [0.0] * num_features
    # Initial prior bias
    pos_count = sum(y_train)
    total = len(y_train)
    weights[0] = math.log((pos_count + 1e-5) / (total - pos_count + 1e-5))

    for epoch in range(epochs):
        grad = [0.0] * num_features
        for x, y in zip(X_train, y_train):
            z = sum(w * f for w, f in zip(weights, x))
            pred = sigmoid(z)
            error = pred - y
            for j in range(num_features):
                grad[j] += error * x[j]

        # Update weights with L2 regularization
        n = len(X_train)
        for j in range(num_features):
            reg = 0.01 * weights[j] if j > 0 else 0.0
            weights[j] -= lr * (grad[j] / n + reg)

    return weights

def evaluate(weights, X_test, y_test):
    preds = []
    brier_sum = 0.0

    for x, y in zip(X_test, y_test):
        z = sum(w * f for w, f in zip(weights, x))
        prob = sigmoid(z)
        preds.append((prob, y))
        brier_sum += (prob - y) ** 2

    brier_score = brier_sum / len(y_test)

    # Calculate ROC-AUC via rank-sum
    preds_sorted = sorted(preds, key=lambda k: k[0])
    n_pos = sum(y for _, y in preds)
    n_neg = len(preds) - n_pos

    if n_pos == 0 or n_neg == 0:
        auc = 0.5
    else:
        rank_sum_pos = sum(i + 1 for i, (_, y) in enumerate(preds_sorted) if y == 1)
        auc = (rank_sum_pos - (n_pos * (n_pos + 1)) / 2.0) / (n_pos * n_neg)

    return auc, brier_score

def main():
    csv_path = os.path.join(os.path.dirname(__file__), "synthetic_appointments.csv")
    records = load_data(csv_path)

    # 1. Chronological time-based split (80% train, 20% test)
    records.sort(key=lambda r: r["date"])
    split_idx = int(len(records) * 0.8)
    train_records = records[:split_idx]
    test_records = records[split_idx:]

    X_train = [extract_features(r) for r in train_records]
    y_train = [float(r["no_show"]) for r in train_records]

    X_test = [extract_features(r) for r in test_records]
    y_test = [float(r["no_show"]) for r in test_records]

    print(f"Dataset split: {len(X_train)} training records, {len(X_test)} evaluation test records.")

    # 2. Train model
    weights = train_logistic_model(X_train, y_train)

    # 3. Evaluate AUC & Calibration (Brier score)
    auc, brier = evaluate(weights, X_test, y_test)
    print(f"Time-based Test ROC-AUC: {auc:.4f}")
    print(f"Brier Calibration Score: {brier:.4f} (closer to 0 is better)")

    # 4. Export model weights to JSON
    feature_names = [
        "intercept",
        "lead_time_normalized",
        "past_misses_normalized",
        "non_attendance_rate",
        "is_unconfirmed",
        "is_confirmed",
        "is_whatsapp",
        "is_weekend",
        "is_late_hour",
        "plan_stage_normalized"
    ]

    export_payload = {
        "disclaimer": "SYNTHETIC_MODEL_WEIGHTS_ONLY - Requires clinic-specific retraining with real historical data",
        "trainedAt": datetime.utcnow().isoformat() + "Z",
        "metrics": {
            "rocAuc": round(auc, 4),
            "brierScore": round(brier, 4),
            "trainSampleSize": len(X_train),
            "testSampleSize": len(X_test)
        },
        "featureWeights": dict(zip(feature_names, [round(w, 5) for w in weights]))
    }

    out_file = os.path.join(os.path.dirname(__file__), "no_show_weights.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(export_payload, f, indent=2)

    print(f"Exported model weights to {out_file}")

if __name__ == "__main__":
    main()
