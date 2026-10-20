import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/appointment_service.dart';
import '../../services/patient_service.dart';
import '../../services/comms_sender_service.dart';
import '../../models/appointment_model.dart';
import '../../models/patient_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/status_badge.dart';
import 'patients/add_patient_screen.dart';
import 'patients/patient_detail_screen.dart';
import 'appointments/add_appointment_screen.dart';
import 'prescriptions/add_prescription_screen.dart';
import '../../widgets/risk_chip.dart';
import '../../widgets/counter_tile.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const DoctorDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _appointmentService = AppointmentService();
  final _patientService = PatientService();
  final _commsService = CommsSenderService();
  String _selectedFilter = 'all'; // 'all' | 'patients' | 'today' | 'pending' | 'due7d' | 'overdue'

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctor = auth.currentUser;
    final doctorId = doctor?.uid ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryNavy,
              child: Text(
                doctor?.name.isNotEmpty == true ? doctor!.name[0].toUpperCase() : 'D',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor?.name ?? 'Dr. Sarah Jenkins',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.slateDark),
                ),
                Text(
                  'CareTrack Clinical Dashboard',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.slateMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: AppTheme.primaryNavy),
            tooltip: 'Register New Patient',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPatientScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<PatientModel>>(
        stream: doctorId.isNotEmpty
            ? _patientService.streamPatients(doctorId)
            : Stream.value(<PatientModel>[]),
        builder: (context, patientSnapshot) {
          final allPatients = patientSnapshot.data ?? [];

          return StreamBuilder<List<AppointmentModel>>(
            stream: doctorId.isNotEmpty
                ? _appointmentService.streamDoctorAppointments(doctorId)
                : Stream.value(<AppointmentModel>[]),
            builder: (context, snapshot) {
              final allAppointments = snapshot.data ?? [];
              final todayStr = DateUtilsHelper.formatStorageDate(DateTime.now());

              // Categories
              final todayAppointments = allAppointments.where((a) => a.date == todayStr).toList();
              final pendingConfirmations = allAppointments.where((a) => a.isPending).toList();

              final followUpsDueToday = <AppointmentModel>[];
              final followUpsDue3Days = <AppointmentModel>[];
              final followUpsDue7Days = <AppointmentModel>[];
              final followUpsOverdue = <AppointmentModel>[];

              for (final appt in allAppointments) {
                if (appt.status == 'Completed' || appt.status == 'Cancelled') continue;
                final targetDate = DateUtilsHelper.parseStorageDate(appt.date);
                final days = DateUtilsHelper.getDaysFromToday(targetDate);

                if (days < 0) {
                  followUpsOverdue.add(appt);
                } else if (days == 0) {
                  followUpsDueToday.add(appt);
                } else if (days > 0 && days <= 3) {
                  followUpsDue3Days.add(appt);
                } else if (days > 3 && days <= 7) {
                  followUpsDue7Days.add(appt);
                }
              }

              // Filter appointments for display list
              List<AppointmentModel> displayedAppointments;
              if (_selectedFilter == 'today') {
                displayedAppointments = todayAppointments;
              } else if (_selectedFilter == 'pending') {
                displayedAppointments = pendingConfirmations;
              } else if (_selectedFilter == 'due7d') {
                displayedAppointments = [...followUpsDue3Days, ...followUpsDue7Days];
              } else if (_selectedFilter == 'overdue') {
                displayedAppointments = followUpsOverdue;
              } else {
                displayedAppointments = allAppointments;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Clinical Header Banner
                    _buildHeroBanner(todayAppointments.length, allPatients.length),
                    const SizedBox(height: 20),

                    // Responsive 4 Counter Tiles (Today, 3 days, 7 days, Overdue in red)
                    _buildKpiGrid(
                      todayCount: todayAppointments.length,
                      due3dCount: followUpsDue3Days.length,
                      due7dCount: followUpsDue7Days.length,
                      overdueCount: followUpsOverdue.length,
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 20),

                    // Overdue Follow-up Card with One-Tap Remind Action
                    if (followUpsOverdue.isNotEmpty) ...[
                      _buildOverdueHeroCard(context, followUpsOverdue, doctorId),
                      const SizedBox(height: 20),
                    ],

                    // Quick Action Buttons Bar
                    _buildQuickActionBar(context),
                    const SizedBox(height: 24),

                    // Recently Registered Patients section
                    if (allPatients.isNotEmpty) ...[
                      _buildRecentPatientsSection(context, allPatients, doctorId),
                      const SizedBox(height: 24),
                    ],

                    // Filter Header and Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedFilter == 'patients' ? 'Patient Records' : 'Appointment Queue',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        Text(
                          _selectedFilter == 'patients'
                              ? '${allPatients.length} registered'
                              : '${displayedAppointments.length} visits',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slateMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Pill Selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All Visits (${allAppointments.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('patients', 'All Patients (${allPatients.length})', isHighlight: true),
                          const SizedBox(width: 8),
                          _buildFilterChip('today', 'Today (${todayAppointments.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('pending', 'Pending Confirmation (${pendingConfirmations.length})', isWarning: pendingConfirmations.isNotEmpty),
                          const SizedBox(width: 8),
                          _buildFilterChip('due7d', 'Due in 7 Days (${followUpsDue3Days.length + followUpsDue7Days.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('overdue', 'Overdue (${followUpsOverdue.length})', isDanger: followUpsOverdue.isNotEmpty),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Render List: Either Patients Directory or Appointments Queue
                    if (_selectedFilter == 'patients')
                      _buildPatientsList(context, allPatients, doctorId)
                    else if (displayedAppointments.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedAppointments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final appt = displayedAppointments[index];
                          return _buildAppointmentCard(appt, doctorId);
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroBanner(int todayCount, int totalPatients) {
    final now = DateTime.now();
    final formattedDate = DateUtilsHelper.formatDisplayDate(now);

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: Colors.white, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '● Clinic Active',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome to CareTrack Clinic Portal',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Managing $totalPatients registered patients with $todayCount visits scheduled for today.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required int todayCount,
    required int due3dCount,
    required int due7dCount,
    required int overdueCount,
    required bool isDesktop,
  }) {
    final tiles = [
      CounterTile(
        label: "Today's Visits",
        count: todayCount,
        subtitle: 'Scheduled visits',
        icon: Icons.calendar_today,
        color: AppTheme.primaryTeal,
        onTap: () => setState(() => _selectedFilter = _selectedFilter == 'today' ? 'all' : 'today'),
      ),
      CounterTile(
        label: 'Due in 3 Days',
        count: due3dCount,
        subtitle: 'Upcoming follow-ups',
        icon: Icons.schedule,
        color: const Color(0xFF2563EB),
        onTap: () => setState(() => _selectedFilter = _selectedFilter == 'due7d' ? 'all' : 'due7d'),
      ),
      CounterTile(
        label: 'Due in 7 Days',
        count: due7dCount,
        subtitle: 'Auto-reminders queued',
        icon: Icons.date_range,
        color: AppTheme.mintAccent,
        onTap: () => setState(() => _selectedFilter = _selectedFilter == 'due7d' ? 'all' : 'due7d'),
      ),
      CounterTile(
        label: 'Overdue Recalls',
        count: overdueCount,
        subtitle: 'Requires action',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.statusMissedText,
        isDanger: true,
        onTap: () => setState(() => _selectedFilter = _selectedFilter == 'overdue' ? 'all' : 'overdue'),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: tiles.map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: t))).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 10),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildOverdueHeroCard(BuildContext context, List<AppointmentModel> overdueList, String doctorId) {
    if (overdueList.isEmpty) return const SizedBox.shrink();
    final firstOverdue = overdueList.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusMissedBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.statusMissedText.withAlpha(51)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.statusMissedText.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.alarm_off, color: AppTheme.statusMissedText, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${overdueList.length} Overdue Patient Follow-up${overdueList.length > 1 ? "s" : ""}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.statusMissedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Immediate attention needed. Tap Remind to dispatch an instant follow-up notification.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.slateMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusMissedText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Remind', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () => _triggerOneTapRemind(context, firstOverdue, doctorId),
          ),
        ],
      ),
    );
  }

  void _triggerOneTapRemind(BuildContext context, AppointmentModel appt, String doctorId) async {
    final patient = await _patientService.getPatient(appt.patientId);
    if (!context.mounted) return;

    if (patient?.phone != null && patient!.phone!.isNotEmpty) {
      _commsService.sendSms(
        doctorId: doctorId,
        patientId: appt.patientId,
        phone: patient.phone!,
        message: 'Dear ${patient.name}, your dental follow-up visit with CareTrack is overdue. Please call our clinic to confirm your visit.',
        context: context,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patient phone number available to remind.')),
      );
    }
  }



  Widget _buildRecentPatientsSection(BuildContext context, List<PatientModel> patients, String doctorId) {
    final recent = patients.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.fiber_new, color: AppTheme.primaryNavy, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Recently Registered Patients',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slateDark,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _selectedFilter = 'patients'),
              child: Text(
                'View All (${patients.length}) →',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 145,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = recent[index];
              return Container(
                width: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${p.age ?? "—"} yrs • ${p.phone ?? p.email ?? "No contact"}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.slateMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Divider(height: 12),
                    // Quick Action communication buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (p.phone != null && p.phone!.isNotEmpty) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            icon: const Icon(Icons.sms_outlined, color: AppTheme.primaryBlue),
                            tooltip: 'Send SMS',
                            onPressed: () => _commsService.openMessageComposerDialog(
                              context: context,
                              doctorId: doctorId,
                              patientId: p.id,
                              patientName: p.name,
                              initialPhone: p.phone,
                              initialEmail: p.email,
                              initialChannel: 'sms',
                              defaultMessage: 'Hello ${p.name}, greeting from Dr. Dental Clinic CareTrack! Your care schedule is active.',
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF10B981)),
                            tooltip: 'WhatsApp',
                            onPressed: () => _commsService.openMessageComposerDialog(
                              context: context,
                              doctorId: doctorId,
                              patientId: p.id,
                              patientName: p.name,
                              initialPhone: p.phone,
                              initialEmail: p.email,
                              initialChannel: 'whatsapp',
                              defaultMessage: 'Hello ${p.name}, greeting from Dr. Dental Clinic CareTrack! Your care schedule is active.',
                            ),
                          ),
                        ],
                        if (p.email != null && p.email!.isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            icon: const Icon(Icons.email_outlined, color: Color(0xFF6366F1)),
                            tooltip: 'Send Email',
                            onPressed: () => _commsService.openMessageComposerDialog(
                              context: context,
                              doctorId: doctorId,
                              patientId: p.id,
                              patientName: p.name,
                              initialPhone: p.phone,
                              initialEmail: p.email,
                              initialChannel: 'email',
                              defaultSubject: 'CareTrack Dental Clinic Care Update',
                              defaultMessage: 'Dear ${p.name},\n\nThank you for choosing our clinic. Your dental care profile is active in CareTrack.\n\nBest regards,\nCareTrack Dental Team',
                            ),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: const Icon(Icons.calendar_month, color: AppTheme.slateDark),
                          tooltip: 'Book Appointment',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddAppointmentScreen(preselectedPatient: p)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientsList(BuildContext context, List<PatientModel> patients, String doctorId) {
    if (patients.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = patients[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryNavy,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(p.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${p.age != null ? "${p.age} yrs • " : ""}${p.phone ?? ""}${p.phone != null && p.email != null ? " • " : ""}${p.email ?? ""}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.phone != null && p.phone!.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.sms_outlined, color: AppTheme.primaryBlue),
                    tooltip: 'Send SMS',
                    onPressed: () => _commsService.openMessageComposerDialog(
                      context: context,
                      doctorId: doctorId,
                      patientId: p.id,
                      patientName: p.name,
                      initialPhone: p.phone,
                      initialEmail: p.email,
                      initialChannel: 'sms',
                      defaultMessage: 'Hello ${p.name}, this is a clinical notice from CareTrack Clinic.',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF10B981)),
                    tooltip: 'WhatsApp',
                    onPressed: () => _commsService.openMessageComposerDialog(
                      context: context,
                      doctorId: doctorId,
                      patientId: p.id,
                      patientName: p.name,
                      initialPhone: p.phone,
                      initialEmail: p.email,
                      initialChannel: 'whatsapp',
                      defaultMessage: 'Hello ${p.name}, this is a clinical notice from CareTrack Clinic.',
                    ),
                  ),
                ],
                if (p.email != null && p.email!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.email_outlined, color: Color(0xFF6366F1)),
                    tooltip: 'Send Email',
                    onPressed: () => _commsService.openMessageComposerDialog(
                      context: context,
                      doctorId: doctorId,
                      patientId: p.id,
                      patientName: p.name,
                      initialPhone: p.phone,
                      initialEmail: p.email,
                      initialChannel: 'email',
                      defaultSubject: 'CareTrack Dental Clinic - Notice',
                      defaultMessage: 'Dear ${p.name},\n\nYour clinical care profile is updated in CareTrack.\n\nBest regards,\nCareTrack Team',
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.slateMuted),
                  onSelected: (val) async {
                    if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Patient Record?'),
                          content: Text('Are you sure you want to permanently delete ${p.name}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.statusDanger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _patientService.deletePatient(p.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Patient ${p.name} deleted.'),
                              backgroundColor: AppTheme.slateDark,
                            ),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppTheme.statusDanger, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Patient', style: TextStyle(color: AppTheme.statusDanger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPatientScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: Text(
                '+ Add Patient',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPrescriptionScreen()),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppTheme.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                foregroundColor: AppTheme.primaryBlue,
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                '+ AI Rx Follow-up',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                foregroundColor: AppTheme.slateDark,
              ),
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(
                '+ Visit',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isHighlight = false, bool isWarning = false, bool isDanger = false}) {
    final isSelected = _selectedFilter == key;

    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppTheme.slateDark;
    Color border = const Color(0xFFE2E8F0);

    if (isSelected) {
      bg = AppTheme.primaryNavy;
      fg = Colors.white;
      border = AppTheme.primaryNavy;
    } else if (isDanger) {
      bg = const Color(0xFFFEF2F2);
      fg = AppTheme.statusDanger;
      border = const Color(0xFFFECACA);
    } else if (isWarning) {
      bg = const Color(0xFFFFFBEB);
      fg = AppTheme.statusWarning;
      border = const Color(0xFFFDE68A);
    } else if (isHighlight) {
      bg = const Color(0xFFEFF6FF);
      fg = AppTheme.primaryBlue;
      border = const Color(0xFFBFDBFE);
    }

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appt, String doctorId) {
    return FutureBuilder<PatientModel?>(
      future: _patientService.getPatient(appt.patientId),
      builder: (context, snapshot) {
        final patient = snapshot.data;
        final patientName = patient?.name ?? 'Loading Patient...';
        final patientPhone = patient?.phone ?? '';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppTheme.softShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          appt.time,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        Text(
                          DateUtilsHelper.formatDisplayDate(DateUtilsHelper.parseStorageDate(appt.date)),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppTheme.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Patient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              appt.type,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            if (patientPhone.isNotEmpty) ...[
                              const Text(' • ', style: TextStyle(color: AppTheme.slateMuted)),
                              Text(
                                patientPhone,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.slateMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status & Risk Badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: appt.confirmationStatus),
                      if (appt.riskScore != null || appt.riskLevel != null) ...[
                        const SizedBox(height: 6),
                        RiskChip(
                          riskScore: appt.riskScore,
                          riskLevel: appt.riskLevel,
                          riskFactors: appt.riskFactors,
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Notes: ${appt.notes}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.slateMedium),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (appt.isPending) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _appointmentService.updateAppointmentStatus(
                          appointmentId: appt.id,
                          status: 'Confirmed',
                          confirmationStatus: 'Confirmed',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appointment marked Confirmed')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        foregroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: Text('Confirm', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      if (patient != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientDetailScreen(patient: patient),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: AppTheme.slateDark,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      'View 360° Journey →',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month_outlined, size: 36, color: AppTheme.slateMuted),
          ),
          const SizedBox(height: 16),
          Text(
            'No appointments in this view',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.slateDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a new patient or follow-up prescription to auto-schedule appointments.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.slateMuted,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPatientScreen()),
            ),
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('+ Register New Patient'),
          ),
        ],
      ),
    );
  }
}

