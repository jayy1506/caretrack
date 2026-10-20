"""
Synthetic Data Generator for Dental Appointment No-Show Prediction.
IMPORTANT: All data generated here is 100% SYNTHETIC for demonstration,
unit testing, and architecture integration. No real patient data is used.
"""

import csv
import random
import datetime

OUTPUT_FILE = "synthetic_appointments.csv"
NUM_RECORDS = 1500

random.seed(42)

def generate_record(idx, base_date):
    # Time progression for time-based split evaluation
    appt_date = base_date + datetime.timedelta(days=int(idx * 0.2))
    
    lead_time_days = random.choices([1, 2, 3, 5, 7, 10, 14, 21, 30], weights=[20, 20, 15, 15, 10, 8, 5, 4, 3])[0]
    day_of_week = appt_date.weekday() # 0 = Monday, 6 = Sunday
    hour = random.choice([9, 10, 11, 12, 14, 15, 16, 17, 18, 19])
    
    past_missed_count = random.choices([0, 1, 2, 3, 4], weights=[65, 20, 10, 3, 2])[0]
    past_attendance_rate = round(max(0.1, min(1.0, 1.0 - (past_missed_count * 0.2) + random.uniform(-0.1, 0.1))), 2)
    
    treatment_plan_stage = random.choices([0, 1, 2, 3, 4], weights=[40, 25, 20, 10, 5])[0] # 0 = routine consult
    reminder_response = random.choices(["confirmed", "unconfirmed", "reschedule_requested"], weights=[60, 30, 10])[0]
    channel = random.choices(["whatsapp", "sms", "email"], weights=[70, 20, 10])[0]
    
    # Ground truth probability heuristic for realistic synthetic simulation
    prob = 0.10 # baseline
    if lead_time_days > 14:
        prob += 0.20
    elif lead_time_days > 7:
        prob += 0.10
        
    if past_missed_count >= 2:
        prob += 0.30
    elif past_missed_count == 1:
        prob += 0.15
        
    if reminder_response == "unconfirmed":
        prob += 0.25
    elif reminder_response == "reschedule_requested":
        prob += 0.15
    elif reminder_response == "confirmed":
        prob -= 0.10
        
    if hour >= 18 or hour <= 9:
        prob += 0.08
        
    prob = max(0.02, min(0.95, prob))
    no_show = 1 if random.random() < prob else 0
    
    return {
        "disclaimer": "SYNTHETIC_DATA_ONLY",
        "appointment_id": f"synth_appt_{idx:05d}",
        "date": appt_date.strftime("%Y-%m-%d"),
        "lead_time_days": lead_time_days,
        "day_of_week": day_of_week,
        "appointment_hour": hour,
        "past_missed_count": past_missed_count,
        "past_attendance_rate": past_attendance_rate,
        "treatment_plan_stage": treatment_plan_stage,
        "reminder_response": reminder_response,
        "channel": channel,
        "no_show": no_show
    }

def main():
    base_date = datetime.date(2026, 1, 1)
    fieldnames = [
        "disclaimer", "appointment_id", "date", "lead_time_days", "day_of_week",
        "appointment_hour", "past_missed_count", "past_attendance_rate",
        "treatment_plan_stage", "reminder_response", "channel", "no_show"
    ]
    
    with open(OUTPUT_FILE, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for i in range(1, NUM_RECORDS + 1):
            writer.writerow(generate_record(i, base_date))
            
    print(f"Generated {NUM_RECORDS} synthetic appointment records in {OUTPUT_FILE}.")

if __name__ == "__main__":
    main()
