import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service & Clinical Care'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryTeal, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Emergency Medical Advisory: CareTrack is a clinical scheduling and patient communication platform. It is NOT an emergency response system. For acute dental trauma, severe hemorrhage, or airway difficulty, contact 108 or report immediately to the nearest hospital emergency department.',
                      style: TextStyle(fontSize: 12, color: AppTheme.primaryNavy, height: 1.4, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. Purpose and Scope',
              'CareTrack facilitates appointment scheduling, dental treatment plan continuity, and medication reminders. The platform provides no billing, invoicing, payments, or financial processing capabilities.',
            ),
            _buildSection(
              '2. Physician Clinical Discretion (Human-in-the-Loop)',
              'All AI-generated outputs—including prescription digitizations, drug-allergy safety flags, and no-show risk scores—are strictly advisory suggestions. The licensed attending doctor retains sole, undelegated clinical responsibility for all medical diagnoses, prescription approvals, and treatment protocols.',
            ),
            _buildSection(
              '3. Appointments and Cancellation Policy',
              'Patients may reschedule or cancel scheduled dental visits via their authenticated WhatsApp confirmation link or by contacting clinic reception up to two (2) hours prior to the slot time. Late cancellations or unattended appointments are recorded to assist doctors in follow-up scheduling.',
            ),
            _buildSection(
              '4. WhatsApp and Communications Protocol',
              'Transactional messages are dispatched strictly to patients who have provided messaging consent. Anti-spam cooldown rules prevent frequent messaging (maximum 1 recall campaign message every 14 days). Inbound patient queries describing fever, acute bleeding, or unmanaged pain are prioritized for immediate clinical staff intervention.',
            ),
            _buildSection(
              '5. Contact and Inquiries',
              'For questions regarding clinic treatment terms, visit scheduling, or care plans:\nCareTrack Dental Clinic • Support Team\nEmail: contact@caretrackclinic.com',
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
