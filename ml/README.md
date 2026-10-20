# Machine Learning: Dental Appointment No-Show Prediction

This directory contains the machine learning training pipeline and synthetic data generators for predicting dental appointment no-show probability.

> **CRITICAL CLINICAL DISCLAIMER**:
> All sample data and pre-trained weights in this directory are generated from **100% SYNTHETIC DATA** for architectural integration, unit testing, and demonstration purposes.
> **The model requires real clinic-specific historical appointment data to produce clinically meaningful and accurate predictions in production.** Never rely on synthetic-trained weights for critical operational decisions without fine-tuning on real clinic data.

## Features Used
1. `lead_time_days`: Number of days between booking time and scheduled appointment.
2. `day_of_week`: Day of the week (weekday vs weekend).
3. `appointment_hour`: Scheduled time of day (morning, afternoon, late evening).
4. `past_missed_count`: Number of past missed/no-show appointments for this patient.
5. `past_attendance_rate`: Historical completed visits vs total scheduled visits.
6. `treatment_plan_stage`: Order of current stage in multi-visit dental plan.
7. `reminder_response`: Current confirmation status (`confirmed`, `unconfirmed`, `reschedule_requested`).
8. `channel`: Communication channel (`whatsapp`, `sms`, `email`).

## Evaluation Methodology
- **Time-Based Split**: Rather than a random shuffle split (which causes data leakage in time series), the first 80% chronologically is used for training, and the most recent 20% is held out for evaluation.
- **Metrics Evaluated**:
  - **ROC-AUC**: Evaluates ranking quality across probability thresholds.
  - **Brier Score / Calibration**: Measures probability calibration quality ($0.0$ is perfect calibration).

## Running Training
```bash
python generate_synthetic_data.py
python train_no_show.py
```
This exports calibrated coefficients to `no_show_weights.json`, which are served deterministically in the Cloud Functions TypeScript backend (`functions/src/services/noShowPredictionService.ts`).
