# Prescription Extraction Evaluation Report

> **Dataset Disclaimer**: Evaluated against SYNTHETIC/SAMPLE labeled prescriptions only. No real patient data is used in automated benchmarking.

## Summary Metrics

| Metric | Score | Target | Status |
| :--- | :--- | :--- | :--- |
| **Medicine Name Accuracy** | **100.0%** | >= 90% | PASS |
| **Dosage Accuracy** | **100.0%** | >= 85% | PASS |
| **Frequency Accuracy** | **100.0%** | >= 85% | PASS |
| **Duration Accuracy** | **100.0%** | >= 85% | PASS |
| **Overall Accuracy** | **100.0%** | >= 85% | PASS |
| **Extraction Precision** | **100.0%** | >= 85% | PASS |
| **Extraction Recall** | **100.0%** | >= 85% | PASS |
| **F1 Score** | **100.0%** | >= 85% | PASS |

- **Total Expected Medicines**: 6
- **Total Extracted Medicines**: 6
- **Matched Medicines Count**: 6

## Sample-by-Sample Breakdown

| Sample ID | Expected | Extracted | Name Score | Dose Score | Freq Score | Duration Score |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `synthetic_sample_01` | 3 | 3 | 100.0% | 100.0% | 100.0% | 100.0% |
| `synthetic_sample_02` | 3 | 3 | 100.0% | 100.0% | 100.0% | 100.0% |

---
*Report generated automatically by CareTrack Prescription Evaluation Runner.*
