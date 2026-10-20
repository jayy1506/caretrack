import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy & Data Handling'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legal Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legal Notice & DPDP Act Compliance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This data handling summary reflects the compliance framework of the Digital Personal Data Protection Act 2023 (DPDP Act, India). Clinics must have this document reviewed by qualified legal counsel prior to real clinical deployment.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. Data Fiduciary and Platform Architecture',
              'The dental clinic operating CareTrack acts as the Data Fiduciary under the DPDP Act 2023. CareTrack acts as a Data Processor providing clinical retention, slot scheduling, and transactional reminder services. All data is scoped strictly by clinicId and stored in secure regional data facilities.',
            ),
            _buildSection(
              '2. Categories of Personal Data Collected',
              '• Patient Identity & Contact: Full name, phone number, email address, age/DOB, and address.\n• Clinical Records: Dental treatment stages, scheduled appointment history, doctor consultation notes, and prescribed medication schedules.\n• Communication Logs: Transactional delivery timestamps and inbound patient messages.',
            ),
            _buildSection(
              '3. Explicit Consent & Purpose Limitation',
              'Personal data is processed exclusively for the purpose of healthcare delivery, treatment continuity, and patient safety:\n• Messaging Consent: Mandatory opt-in for appointment reminders and medication schedules via WhatsApp/SMS. Patients can withdraw consent at any time by replying "STOP" or notifying clinic staff.\n• AI Processing Consent: Human-in-the-loop clinical assistance for handwritten prescription digitization and no-show prediction. AI outputs are strictly suggestions that require licensed doctor verification before taking effect.',
            ),
            _buildSection(
              '4. Data Retention & Right to Erasure',
              'Patients have the statutory right under the DPDP Act to request:\n• Data Portability: Export of complete personal medical records in structured JSON format.\n• Right to Erasure: Permanent removal of personal identifiers, conversation records, and cloud storage images upon written request or clinic discharge, subject to applicable Indian medical council retention laws.',
            ),
            _buildSection(
              '5. Security & Multi-Clinic Isolation',
              'Zero patient PII is recorded in plaintext system logs. Role-based access control enforces strict boundaries: receptionists cannot view clinical doctor notes, doctors access their assigned patients, and clinic owners manage administrative records.',
            ),
            _buildSection(
              '6. Grievance Redressal Officer',
              'For privacy concerns, consent withdrawal, or erasure requests, patients may contact the Clinic Privacy Officer at:\nEmail: privacy@caretrackclinic.com\nPhone: +91 98765 43210\nAddress: CareTrack Dental Clinic, Bandra West, Mumbai, MH',
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'CareTrack Platform • Version 2.0 (DPDP Aligned)',
                style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: AppTheme.slateDark, height: 1.5),
          ),
        ],
      ),
    );
  }
}
