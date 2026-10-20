import { AppointmentDocument } from '../types/index.js';

export interface NoShowPredictionInput {
  leadTimeDays: number;
  appointmentDate: string; // YYYY-MM-DD
  appointmentTime: string; // HH:mm or HH:mm AM/PM
  pastMissedCount: number;
  pastAttendanceRate: number; // 0.0 to 1.0
  treatmentPlanStageOrder?: number;
  confirmationStatus?: string; // 'Confirmed' | 'Pending' | 'Reschedule Requested'
  channel?: string; // 'whatsapp' | 'sms' | 'email'
}

export interface NoShowPredictionResult {
  riskScore: number; // 0.00 to 1.00
  riskLevel: 'low' | 'medium' | 'high';
  riskFactors: string[];
}

export class NoShowPredictionService {
  // Calibrated weights from training pipeline
  private static WEIGHTS = {
    intercept: -1.1459,
    leadTimeNorm: 0.22528,
    pastMissesNorm: 0.42859,
    nonAttendanceRate: 0.32569,
    isUnconfirmed: 0.66493,
    isConfirmed: -0.80511,
    isWhatsapp: -0.05338,
    isWeekend: 0.03974,
    isLateHour: 0.20073,
    planStageNorm: -0.00862,
  };

  /**
   * Calculates appointment no-show probability and risk level.
   */
  public static predict(input: NoShowPredictionInput): NoShowPredictionResult {
    const riskFactors: string[] = [];

    const leadTime = Math.max(0, input.leadTimeDays || 0);
    const pastMisses = Math.max(0, input.pastMissedCount || 0);
    const attendanceRate = Math.max(0, Math.min(1.0, input.pastAttendanceRate ?? 1.0));
    const nonAttendance = 1.0 - attendanceRate;
    const planStage = Math.max(0, input.treatmentPlanStageOrder || 0);

    // Date & hour extraction
    let isWeekend = false;
    try {
      const d = new Date(input.appointmentDate);
      const day = d.getDay(); // 0 is Sun, 6 is Sat
      if (day === 0 || day === 6) {
        isWeekend = true;
      }
    } catch {
      // fallback
    }

    let hour = 10;
    if (input.appointmentTime) {
      const match = input.appointmentTime.match(/(\d+):(\d+)(?:\s*(AM|PM))?/i);
      if (match) {
        let h = parseInt(match[1], 10);
        const meridiem = (match[3] || '').toUpperCase();
        if (meridiem === 'PM' && h < 12) h += 12;
        if (meridiem === 'AM' && h === 12) h = 0;
        hour = h;
      }
    }
    const isLateHour = hour >= 18 || hour <= 9;

    const confStatus = (input.confirmationStatus || 'Pending').toLowerCase();
    const isConfirmed = confStatus === 'confirmed';
    const isUnconfirmed = confStatus === 'pending' || confStatus === 'reschedule requested' || confStatus === 'declined';
    const isWhatsapp = (input.channel || 'whatsapp').toLowerCase() === 'whatsapp';

    // Calculate linear logit
    let z = this.WEIGHTS.intercept;
    z += Math.min(leadTime / 30.0, 1.0) * this.WEIGHTS.leadTimeNorm;
    z += Math.min(pastMisses / 4.0, 1.0) * this.WEIGHTS.pastMissesNorm;
    z += nonAttendance * this.WEIGHTS.nonAttendanceRate;
    z += (isUnconfirmed ? 1.0 : 0.0) * this.WEIGHTS.isUnconfirmed;
    z += (isConfirmed ? 1.0 : 0.0) * this.WEIGHTS.isConfirmed;
    z += (isWhatsapp ? 1.0 : 0.0) * this.WEIGHTS.isWhatsapp;
    z += (isWeekend ? 1.0 : 0.0) * this.WEIGHTS.isWeekend;
    z += (isLateHour ? 1.0 : 0.0) * this.WEIGHTS.isLateHour;
    z += Math.min(planStage / 4.0, 1.0) * this.WEIGHTS.planStageNorm;

    // Sigmoid function
    const clampedZ = Math.max(-20.0, Math.min(20.0, z));
    const rawProb = 1.0 / (1.0 + Math.exp(-clampedZ));
    const riskScore = Math.round(rawProb * 100) / 100;

    // Identify qualitative risk factors for clinicians
    if (pastMisses >= 2) {
      riskFactors.push(`High past no-shows (${pastMisses} missed appointments)`);
    } else if (pastMisses === 1) {
      riskFactors.push('1 previous missed appointment');
    }

    if (leadTime >= 14) {
      riskFactors.push(`Long advance booking lead time (${leadTime} days)`);
    } else if (leadTime >= 7) {
      riskFactors.push(`Moderate booking lead time (${leadTime} days)`);
    }

    if (isUnconfirmed) {
      riskFactors.push('Reminder unconfirmed');
    }

    if (attendanceRate < 0.7 && pastMisses > 0) {
      riskFactors.push(`Low historical attendance rate (${Math.round(attendanceRate * 100)}%)`);
    }

    if (isLateHour) {
      riskFactors.push('Off-peak schedule hour');
    }

    let riskLevel: 'low' | 'medium' | 'high' = 'low';
    if (riskScore >= 0.55) {
      riskLevel = 'high';
    } else if (riskScore >= 0.30) {
      riskLevel = 'medium';
    }

    return {
      riskScore,
      riskLevel,
      riskFactors,
    };
  }

  /**
   * Evaluates appointment model directly and extracts relevant features.
   */
  public static evaluateAppointment(
    appointment: AppointmentDocument,
    patientHistory?: {
      pastMissedCount: number;
      totalAppointments: number;
      treatmentPlanStage?: number;
    }
  ): NoShowPredictionResult {
    const apptDate = new Date(`${appointment.date}T10:00:00Z`);
    const createdDate = appointment.createdAt
      ? new Date((appointment.createdAt as any).toDate ? (appointment.createdAt as any).toDate() : appointment.createdAt)
      : new Date();

    const diffMs = apptDate.getTime() - createdDate.getTime();
    const leadTimeDays = Math.max(0, Math.round(diffMs / (1000 * 60 * 60 * 24)));

    const pastMissed = patientHistory?.pastMissedCount || 0;
    const totalAppts = patientHistory?.totalAppointments || 0;
    const attendanceRate = totalAppts > 0 ? (totalAppts - pastMissed) / totalAppts : 1.0;

    return this.predict({
      leadTimeDays,
      appointmentDate: appointment.date,
      appointmentTime: appointment.time,
      pastMissedCount: pastMissed,
      pastAttendanceRate: attendanceRate,
      treatmentPlanStageOrder: patientHistory?.treatmentPlanStage || 0,
      confirmationStatus: appointment.confirmationStatus,
      channel: 'whatsapp',
    });
  }
}
