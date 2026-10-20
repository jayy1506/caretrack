import nodemailer, { Transporter } from 'nodemailer';
import { config } from '../config/index.js';

export interface SendEmailParams {
  to: string;
  subject: string;
  html: string;
}

export interface EmailResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

let transporter: Transporter | null = null;

function getTransporter(): Transporter | null {
  if (!transporter && config.gmailUser && config.gmailAppPassword) {
    transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: {
        user: config.gmailUser,
        pass: config.gmailAppPassword,
      },
    });
  }
  return transporter;
}

/**
 * Sends an email using Nodemailer via Gmail SMTP.
 * Never throws; always returns { success, messageId?, error? }.
 */
export async function sendEmail(params: SendEmailParams): Promise<EmailResult> {
  try {
    if (!config.gmailUser || !config.gmailAppPassword) {
      return {
        success: false,
        error: 'Gmail SMTP not configured (GMAIL_USER or GMAIL_APP_PASSWORD missing)',
      };
    }

    const mailer = getTransporter();
    if (!mailer) {
      return {
        success: false,
        error: 'Failed to initialize Gmail SMTP transporter',
      };
    }

    const info = await mailer.sendMail({
      from: `"CareTrack Clinic" <${config.gmailUser}>`,
      to: params.to,
      subject: params.subject,
      html: params.html,
    });

    return {
      success: true,
      messageId: info.messageId,
    };
  } catch (err: any) {
    return {
      success: false,
      error: err?.message || 'Unknown email delivery error',
    };
  }
}

export class EmailService {
  public static isConfigured(): boolean {
    return Boolean(config.gmailUser && config.gmailAppPassword);
  }

  public static async sendEmail(params: SendEmailParams): Promise<EmailResult> {
    return sendEmail(params);
  }

  // --- Clinical Email Templates ---

  public static getPatientRegistrationTemplate(patientName: string, doctorName: string, clinicPhone?: string): string {
    return `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 8px; color: #1e293b;">
        <h2 style="color: #1e3a8a; margin-top: 0;">Welcome to CareTrack</h2>
        <p>Dear <strong>${patientName}</strong>,</p>
        <p>You have been registered with <strong>Dr. ${doctorName}</strong>.</p>
        <p>Your clinic records, upcoming appointments, and follow-up reminders will be managed reliably through our clinic care system.</p>
        ${clinicPhone ? `<p>Clinic Contact: <strong>${clinicPhone}</strong></p>` : ''}
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="font-size: 12px; color: #64748b;">This is an automated notification from CareTrack Clinic Management.</p>
      </div>
    `;
  }

  public static getAppointmentConfirmationTemplate(params: {
    patientName: string;
    doctorName: string;
    appointmentDate: string;
    appointmentTime: string;
    appointmentType: string;
    confirmUrl: string;
    rescheduleUrl: string;
  }): string {
    return `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 8px; color: #1e293b;">
        <h2 style="color: #1e3a8a; margin-top: 0;">Appointment Scheduled</h2>
        <p>Dear <strong>${params.patientName}</strong>,</p>
        <p>Your appointment with <strong>Dr. ${params.doctorName}</strong> has been scheduled:</p>
        
        <div style="background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 16px; margin: 20px 0;">
          <p style="margin: 4px 0;"><strong>Date:</strong> ${params.appointmentDate}</p>
          <p style="margin: 4px 0;"><strong>Time:</strong> ${params.appointmentTime}</p>
          <p style="margin: 4px 0;"><strong>Type:</strong> ${params.appointmentType}</p>
        </div>

        <p>Please confirm your attendance:</p>
        <div style="margin: 24px 0;">
          <a href="${params.confirmUrl}" style="background-color: #1e3a8a; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block; margin-right: 12px;">Confirm Appointment</a>
          <a href="${params.rescheduleUrl}" style="background-color: #f1f5f9; color: #334155; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; border: 1px solid #cbd5e1; display: inline-block;">Request Reschedule</a>
        </div>

        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="font-size: 12px; color: #64748b;">CareTrack Automated Appointment System</p>
      </div>
    `;
  }

  public static getAppointmentReminderTemplate(params: {
    patientName: string;
    doctorName: string;
    appointmentDate: string;
    appointmentTime: string;
    appointmentType: string;
  }): string {
    return `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 8px; color: #1e293b;">
        <h2 style="color: #1e3a8a; margin-top: 0;">Appointment Reminder</h2>
        <p>Dear <strong>${params.patientName}</strong>,</p>
        <p>This is a reminder of your upcoming appointment with <strong>Dr. ${params.doctorName}</strong> tomorrow:</p>
        
        <div style="background-color: #eff6ff; border: 1px solid #bfdbfe; border-radius: 6px; padding: 16px; margin: 20px 0;">
          <p style="margin: 4px 0;"><strong>Date:</strong> ${params.appointmentDate}</p>
          <p style="margin: 4px 0;"><strong>Time:</strong> ${params.appointmentTime}</p>
          <p style="margin: 4px 0;"><strong>Type:</strong> ${params.appointmentType}</p>
        </div>

        <p>Please arrive 10 minutes before your scheduled appointment time.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="font-size: 12px; color: #64748b;">CareTrack Notification Engine</p>
      </div>
    `;
  }
}
