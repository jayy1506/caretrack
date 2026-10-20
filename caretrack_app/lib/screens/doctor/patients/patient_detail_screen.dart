import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../models/patient_model.dart';
import '../../../models/prescription_model.dart';
import '../../../models/appointment_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/timeline_event_model.dart';
import '../../../services/patient_service.dart';
import '../../../services/prescription_service.dart';
import '../../../services/appointment_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/timeline_service.dart';
import '../../../services/comms_sender_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../prescriptions/add_prescription_screen.dart';
import '../appointments/add_appointment_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final PatientModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _patientService = PatientService();
  final _prescriptionService = PrescriptionService();
  final _appointmentService = AppointmentService();
  final _notificationService = NotificationTrackingService();
  final _timelineService = TimelineService();
  final _commsService = CommsSenderService();
  late PatientModel _patient;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final isViewOnly = user?.isViewOnly == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_patient.name),
        actions: [
          if (isViewOnly)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 12, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text(
                    'Read Only',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          if (!isViewOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.statusDanger),
              tooltip: 'Delete Patient',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Patient Record?'),
                  content: Text('Are you sure you want to permanently delete ${widget.patient.name} and all medical records?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.statusDanger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete Permanently'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                _patientService.deletePatient(widget.patient.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Patient ${widget.patient.name} deleted.'),
                      backgroundColor: AppTheme.slateDark,
                    ),
                  );
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryNavy,
          unselectedLabelColor: AppTheme.slateMuted,
          indicatorColor: AppTheme.primaryNavy,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Appointments'),
            Tab(text: 'Timeline'),
            Tab(text: 'Communication'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(user),
          _buildPrescriptionsTab(),
          _buildAppointmentsTab(),
          _buildTimelineTab(),
          _buildCommunicationTab(),
        ],
      ),
    );
  }

  // --- TAB 1: OVERVIEW ---
  Widget _buildOverviewTab(UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Demographics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _patient.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slateDark,
                        ),
                      ),
                      StatusBadge(status: _patient.status.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildDetailRow('Age / DOB', '${_patient.age ?? "—"} yrs • ${_patient.dateOfBirth ?? "Not set"}'),
                  _buildDetailRow('Mobile Phone', _patient.phone ?? 'Not specified'),
                  _buildDetailRow('Email Address', _patient.email ?? 'Not specified'),
                  _buildDetailRow('Address', _patient.address ?? 'Not specified'),
                  _buildDetailRow('Registered On', DateUtilsHelper.formatDisplayDate(_patient.createdAt)),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  // Direct Instant Comms Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_patient.phone != null && _patient.phone!.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => _commsService.openMessageComposerDialog(
                            context: context,
                            doctorId: _patient.doctorId,
                            patientId: _patient.id,
                            patientName: _patient.name,
                            initialPhone: _patient.phone,
                            initialEmail: _patient.email,
                            initialChannel: 'sms',
                            defaultMessage: 'Hello ${_patient.name}, this is CareTrack Dental Clinic regarding your treatment follow-up and next routine checkup.',
                          ),
                          icon: const Icon(Icons.sms_outlined, size: 16, color: AppTheme.primaryBlue),
                          label: const Text('Send SMS'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _commsService.openMessageComposerDialog(
                            context: context,
                            doctorId: _patient.doctorId,
                            patientId: _patient.id,
                            patientName: _patient.name,
                            initialPhone: _patient.phone,
                            initialEmail: _patient.email,
                            initialChannel: 'whatsapp',
                            defaultMessage: 'Hello ${_patient.name}, this is CareTrack Dental Clinic regarding your treatment follow-up and next routine checkup.',
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF10B981)),
                          label: const Text('WhatsApp'),
                        ),
                      ],
                      if (_patient.email != null && _patient.email!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _commsService.openMessageComposerDialog(
                            context: context,
                            doctorId: _patient.doctorId,
                            patientId: _patient.id,
                            patientName: _patient.name,
                            initialPhone: _patient.phone,
                            initialEmail: _patient.email,
                            initialChannel: 'email',
                            defaultSubject: 'CareTrack Dental Clinic Care Update',
                            defaultMessage: 'Dear ${_patient.name},\n\nYour clinical profile is active in CareTrack. Please let us know if you have any questions.\n\nBest regards,\nCareTrack Team',
                          ),
                          icon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF6366F1)),
                          label: const Text('Send Email'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // DPDP Consent Status Card
          _buildConsentCard(user),
          const SizedBox(height: 16),

          // Owner Compliance & Data Rights (Export / Erase)
          _buildDataRightsCard(user),
          const SizedBox(height: 16),

          // Routine Checkup Quick Recall Card (1, 2, or 3 Months)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event_repeat, color: Color(0xFF15803D), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule Routine Checkup Recall',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                          Text(
                            '1-Tap schedule & auto-dispatch WhatsApp + SMS + Email to patient',
                            style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _scheduleRoutineCheckup(1),
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: const Text('1 Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _scheduleRoutineCheckup(2),
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: const Text('2 Months', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _scheduleRoutineCheckup(3),
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: const Text('3 Months', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: '+ Add Prescription',
                  icon: Icons.medication_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPrescriptionScreen(patient: widget.patient),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: '+ Schedule Visit',
                  variant: ButtonVariant.outline,
                  icon: Icons.calendar_month_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddAppointmentScreen(preselectedPatient: widget.patient),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleRoutineCheckup(int months) async {
    final targetDate = DateTime.now().add(Duration(days: months * 30));
    final dateStr = DateUtilsHelper.formatStorageDate(targetDate);
    const timeStr = '10:00 AM';

    await _appointmentService.createAppointment(
      doctorId: widget.patient.doctorId,
      patientId: widget.patient.id,
      date: dateStr,
      time: timeStr,
      type: 'Routine Checkup',
      reason: 'Routine Dental Checkup & Scaling ($months-Month Recall)',
    );

    if (!mounted) return;

    // Send automated Clinic Notification & Email
    if (widget.patient.phone != null && widget.patient.phone!.isNotEmpty) {
      _commsService.sendSms(
        doctorId: widget.patient.doctorId,
        patientId: widget.patient.id,
        phone: widget.patient.phone!,
        message: 'Dear ${widget.patient.name}, your $months-month routine dental checkup is scheduled for $dateStr at $timeStr with CareTrack Clinic.',
        context: context,
      );
    }

    if (widget.patient.email != null && widget.patient.email!.isNotEmpty) {
      _commsService.sendEmail(
        doctorId: widget.patient.doctorId,
        patientId: widget.patient.id,
        email: widget.patient.email!,
        subject: 'Routine Dental Checkup Appointment Confirmed',
        body: 'Dear ${widget.patient.name},\n\nYour $months-month routine dental checkup has been scheduled for $dateStr at $timeStr.\n\nBest regards,\nCareTrack Dental Team',
        context: context,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$months-Month Routine Checkup scheduled on $dateStr! Reminder queued.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      setState(() {});
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppTheme.slateDark, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard(UserModel? user) {
    final consent = _patient.consentRecord;
    final msgActive = consent.messagingConsent;
    final aiActive = consent.aiProcessingConsent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: AppTheme.primaryNavy, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DPDP Consent Status',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slateDark),
                      ),
                      Text(
                        'Digital Personal Data Protection Act (India)',
                        style: TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                      ),
                    ],
                  ),
                ],
              ),
              if (user?.canEdit == true)
                TextButton.icon(
                  onPressed: _openConsentDialog,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Update', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: msgActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: msgActive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            msgActive ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: msgActive ? const Color(0xFF16A34A) : AppTheme.statusDanger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Messaging',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: msgActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msgActive ? 'Consented (${consent.messagingConsentMethod.replaceAll('_', ' ')})' : 'Opted Out',
                        style: TextStyle(
                          fontSize: 11,
                          color: msgActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: aiActive ? const Color(0xFFF5F3FF) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: aiActive ? const Color(0xFFDDD6FE) : const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            aiActive ? Icons.smart_toy_outlined : Icons.cancel,
                            size: 16,
                            color: aiActive ? const Color(0xFF7C3AED) : AppTheme.statusDanger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Processing',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: aiActive ? const Color(0xFF5B21B6) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        aiActive ? 'Consented (${consent.aiProcessingConsentMethod.replaceAll('_', ' ')})' : 'Opted Out',
                        style: TextStyle(
                          fontSize: 11,
                          color: aiActive ? const Color(0xFF6D28D9) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataRightsCard(UserModel? user) {
    if (user?.isOwner != true) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Data Rights (Owner Only)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slateDark),
                    ),
                    Text(
                      'DPDP Act 2023: Right to Access and Right to Erasure',
                      style: TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppTheme.primaryNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _exportHealthRecords,
                  icon: const Icon(Icons.download_outlined, size: 16, color: AppTheme.primaryNavy),
                  label: const Text(
                    'Export JSON',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppTheme.statusDanger),
                    foregroundColor: AppTheme.statusDanger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _confirmErasePatientData,
                  icon: const Icon(Icons.delete_forever_outlined, size: 16),
                  label: const Text(
                    'Erase Data (DPDP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openConsentDialog() async {
    bool msgConsent = _patient.consentRecord.messagingConsent;
    String msgMethod = _patient.consentRecord.messagingConsentMethod;
    bool aiConsent = _patient.consentRecord.aiProcessingConsent;
    String aiMethod = _patient.consentRecord.aiProcessingConsentMethod;
    final notesCtrl = TextEditingController(text: _patient.consentRecord.consentNotes ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Update DPDP Consent'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record explicit consent from the patient as required by the Digital Personal Data Protection Act 2023.',
                      style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('WhatsApp & SMS Messaging', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Send appointment reminders and treatment updates', style: TextStyle(fontSize: 11)),
                      value: msgConsent,
                      onChanged: (val) => setDialogState(() => msgConsent = val),
                    ),
                    if (msgConsent) ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: msgMethod,
                        decoration: const InputDecoration(
                          labelText: 'Messaging Consent Method',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'in_person', child: Text('In-Person Verbal / Clinic Visit')),
                          DropdownMenuItem(value: 'whatsapp_opt_in', child: Text('WhatsApp Opt-In Message')),
                          DropdownMenuItem(value: 'web_booking', child: Text('Online Slot Booking Form')),
                          DropdownMenuItem(value: 'paper_form', child: Text('Physical Intake Paper Form')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => msgMethod = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('AI Prescription & Care Analysis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Allow AI models to parse prescriptions & suggest recalls', style: TextStyle(fontSize: 11)),
                      value: aiConsent,
                      onChanged: (val) => setDialogState(() => aiConsent = val),
                    ),
                    if (aiConsent) ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: aiMethod,
                        decoration: const InputDecoration(
                          labelText: 'AI Consent Method',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'in_person', child: Text('In-Person Verbal / Clinic Visit')),
                          DropdownMenuItem(value: 'web_booking', child: Text('Online Booking Intake Form')),
                          DropdownMenuItem(value: 'paper_form', child: Text('Physical Intake Paper Form')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => aiMethod = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Consent Audit Notes (Optional)',
                        hintText: 'e.g. Signed on paper form during consultation',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Consent'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      try {
        await _patientService.updateConsent(
          patientId: _patient.id,
          clinicId: _patient.clinicId,
          messagingConsent: msgConsent,
          messagingConsentMethod: msgMethod,
          aiProcessingConsent: aiConsent,
          aiProcessingConsentMethod: aiMethod,
          consentNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );

        final newRecord = PatientConsentRecord(
          messagingConsent: msgConsent,
          messagingConsentMethod: msgMethod,
          messagingConsentTimestamp: DateTime.now(),
          aiProcessingConsent: aiConsent,
          aiProcessingConsentMethod: aiMethod,
          aiProcessingConsentTimestamp: DateTime.now(),
          consentNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );

        setState(() {
          _patient = PatientModel(
            id: _patient.id,
            clinicId: _patient.clinicId,
            doctorId: _patient.doctorId,
            name: _patient.name,
            age: _patient.age,
            dateOfBirth: _patient.dateOfBirth,
            phone: _patient.phone,
            email: _patient.email,
            address: _patient.address,
            status: _patient.status,
            allergies: _patient.allergies,
            preferredReminderHour: _patient.preferredReminderHour,
            messagingConsent: msgConsent,
            aiProcessingConsent: aiConsent,
            consentRecord: newRecord,
            createdAt: _patient.createdAt,
            updatedAt: DateTime.now(),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient DPDP consent updated and logged to audit trail.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update consent: $e'),
              backgroundColor: AppTheme.statusDanger,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportHealthRecords() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final data = await _patientService.exportPatientData(
        patientId: _patient.id,
        clinicId: _patient.clinicId,
      );

      if (mounted) Navigator.pop(context); // close loader
      if (!mounted) return;

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Health Records (JSON)'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete structured health record export in accordance with DPDP Act 2023 data portability rights.',
                  style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 250,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Health records JSON copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy JSON'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    }
  }

  Future<void> _confirmErasePatientData() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusDanger),
            SizedBox(width: 8),
            Text('Erase Patient Data (DPDP)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Under DPDP Act 2023 Right to Erasure, this operation will permanently anonymize clinical records, delete prescription scans from storage, and record a sanitized audit event.',
              style: TextStyle(fontSize: 13, color: AppTheme.slateDark),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Clinical / Legal Reason for Erasure *',
                hintText: 'e.g. Patient explicit withdrawal of consent',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reason for erasure is required.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Permanent Erasure'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        await _patientService.erasePatientData(
          patientId: _patient.id,
          reason: reasonCtrl.text.trim(),
          clinicId: _patient.clinicId,
        );

        if (mounted) Navigator.pop(context); // close loader
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient records permanently erased under DPDP Act.'),
              backgroundColor: AppTheme.slateDark,
            ),
          );
          Navigator.pop(context); // leave patient detail
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erasure error: $e'), backgroundColor: AppTheme.statusDanger),
          );
        }
      }
    }
  }

  // --- TAB 2: PRESCRIPTIONS ---
  Widget _buildPrescriptionsTab() {
    return StreamBuilder<List<PrescriptionModel>>(
      stream: _prescriptionService.streamPatientPrescriptions(widget.patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data ?? [];

        if (prescriptions.isEmpty) {
          return EmptyStateView(
            icon: Icons.medication_outlined,
            title: 'No Prescriptions Recorded',
            description: 'Add a prescription manually or upload an image to track medicines and follow-ups.',
            actionText: 'Add Prescription',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddPrescriptionScreen(patient: widget.patient),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: prescriptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final pres = prescriptions[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long, color: AppTheme.primaryNavy, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Prescription: ${pres.prescriptionDate}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        if (pres.aiExtracted)
                          const StatusBadge(status: 'AI Verified')
                        else
                          const StatusBadge(status: 'Manual'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Medicines list
                    const Text('Medicines Prescribed:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateMuted)),
                    const SizedBox(height: 6),
                    ...pres.medicines.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: AppTheme.slateDark),
                                children: [
                                  TextSpan(text: m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (m.dosage.isNotEmpty) TextSpan(text: ' — ${m.dosage}'),
                                  if (m.frequency.isNotEmpty) TextSpan(text: ' (${m.frequency})'),
                                  if (m.duration.isNotEmpty) TextSpan(text: ', ${m.duration}'),
                                  if (m.instructions.isNotEmpty) TextSpan(text: ' [${m.instructions}]', style: const TextStyle(color: AppTheme.slateMuted)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.statusPurpleBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_repeat, color: AppTheme.statusPurple, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Follow-up due: ${pres.followUpDate} (${pres.followUpType.replaceAll("_", " ")})',
                            style: const TextStyle(
                              color: AppTheme.statusPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 3: APPOINTMENTS ---
  Widget _buildAppointmentsTab() {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _appointmentService.streamPatientAppointments(widget.patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data ?? [];

        if (appointments.isEmpty) {
          return EmptyStateView(
            icon: Icons.calendar_month_outlined,
            title: 'No Appointments Scheduled',
            description: 'Schedule a follow-up or consultation for this patient.',
            actionText: 'Schedule Visit',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddAppointmentScreen(preselectedPatient: widget.patient),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final appt = appointments[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${appt.date} at ${appt.time}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        StatusBadge(status: appt.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${appt.type} • Confirmation: ${appt.confirmationStatus}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                    ),
                    if (appt.reason != null && appt.reason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Reason: ${appt.reason}', style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Actions row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (appt.status != 'Completed' && appt.status != 'Cancelled') ...[
                          TextButton(
                            onPressed: () async {
                              await _appointmentService.updateAppointmentStatus(
                                appointmentId: appt.id,
                                status: 'Completed',
                              );
                            },
                            child: const Text('Mark Completed', style: TextStyle(color: AppTheme.statusSuccess, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await _appointmentService.updateAppointmentStatus(
                                appointmentId: appt.id,
                                status: 'Missed',
                              );
                            },
                            child: const Text('Mark Missed', style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 4: TIMELINE (Feature 1: Smart Patient Timeline) ---
  Widget _buildTimelineTab() {
    return FutureBuilder<List<TimelineEventModel>>(
      future: _timelineService.getPatientTimeline(widget.patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return const EmptyStateView(
            icon: Icons.timeline,
            title: 'No Timeline Events',
            description: 'Patient activity timeline will populate automatically as actions occur.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isLast = index == events.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date column
                  SizedBox(
                    width: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateUtilsHelper.formatShortDate(event.timestamp),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        Text(
                          DateUtilsHelper.formatTime(event.timestamp),
                          style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                        ),
                      ],
                    ),
                  ),

                  // Node and vertical line
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: event.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: event.color, width: 2),
                        ),
                        child: Icon(event.icon, size: 12, color: event.color),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppTheme.borderGrey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Event content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.slateDark,
                            ),
                          ),
                          if (event.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.subtitle!,
                              style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                            ),
                          ],
                          if (event.details != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.details!,
                              style: TextStyle(fontSize: 12, color: event.color, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 5: COMMUNICATION HISTORY (Feature 6) ---
  Widget _buildCommunicationTab() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamPatientNotifications(widget.patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return const EmptyStateView(
            icon: Icons.outgoing_mail,
            title: 'No Communication Records',
            description: 'SMS, Email, and Push notification delivery records will be logged here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            final channelIcon = log.channel == 'email'
                ? Icons.email_outlined
                : (log.channel == 'sms' ? Icons.sms_outlined : Icons.notifications_active_outlined);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(channelIcon, size: 20, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                log.readableType,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              StatusBadge(status: log.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recipient: ${log.recipient}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.slateDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateUtilsHelper.formatDateTime(log.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                          ),
                          if (log.error != null && log.error!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.statusDangerBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Error: ${log.error}',
                                style: const TextStyle(color: AppTheme.statusDanger, fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
