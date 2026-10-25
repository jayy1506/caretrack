import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/appointment_service.dart';
import '../../../services/patient_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/patient_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../widgets/risk_chip.dart';
import 'add_appointment_screen.dart';

class AppointmentListScreen extends StatefulWidget {
  final int initialTabIndex;
  const AppointmentListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> with SingleTickerProviderStateMixin {
  final _appointmentService = AppointmentService();
  final _patientService = PatientService();
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctorId = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Appointment',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.mintTeal,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Missed'),
            Tab(text: 'Reschedule Requests'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Week calendar strip
          _buildWeekCalendarStrip(),
          const Divider(height: 1),

          // Tab content
          Expanded(
            child: StreamBuilder<List<AppointmentModel>>(
              stream: _appointmentService.streamDoctorAppointments(doctorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allAppointments = snapshot.data ?? [];
                final todayStr = DateUtilsHelper.formatStorageDate(DateTime.now());
                final selectedDateStr = DateUtilsHelper.formatStorageDate(_selectedDate);

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Today / Selected date
                    _buildAppointmentList(
                      allAppointments.where((a) => a.date == selectedDateStr).toList(),
                      emptyTitle: 'No Visits on ${_formatSelectedDateHeader(_selectedDate)}',
                      emptyDesc: 'No appointments are booked for the selected calendar day.',
                    ),

                    // Tab 2: Upcoming
                    _buildAppointmentList(
                      allAppointments.where((a) => a.date.compareTo(todayStr) > 0 && a.status != 'Cancelled').toList(),
                      emptyTitle: 'No Upcoming Appointments',
                      emptyDesc: 'There are no future visits currently scheduled.',
                    ),

                    // Tab 3: Missed
                    _buildAppointmentList(
                      allAppointments.where((a) => a.status == 'Missed' || (a.date.compareTo(todayStr) < 0 && a.status == 'Scheduled')).toList(),
                      emptyTitle: 'No Missed Visits',
                      emptyDesc: 'All scheduled patient visits are up to date.',
                    ),

                    // Tab 4: Reschedule Requests
                    _buildAppointmentList(
                      allAppointments.where((a) => a.isRescheduleRequested).toList(),
                      emptyTitle: 'No Pending Reschedule Requests',
                      emptyDesc: 'No patients have requested to change their visit timings.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatSelectedDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  // --- WEEK CALENDAR STRIP ---
  Widget _buildWeekCalendarStrip() {
    final now = DateTime.now();
    // Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = days[index];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _tabController.animateTo(0); // Hop to Today/Selected tab
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryNavy
                    : (isToday ? AppTheme.primaryTeal.withAlpha(20) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppTheme.primaryTeal, width: 1.5)
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    dayNames[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : AppTheme.slateMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isToday ? AppTheme.primaryTeal : AppTheme.slateDark),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAppointmentList(
    List<AppointmentModel> list, {
    required String emptyTitle,
    required String emptyDesc,
  }) {
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.calendar_month_outlined,
        title: emptyTitle,
        description: emptyDesc,
        actionText: 'Book New Appointment',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final appt = list[index];
        return _buildAppointmentCard(appt);
      },
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appt) {
    return FutureBuilder<PatientModel?>(
      future: _patientService.getPatient(appt.patientId),
      builder: (context, snapshot) {
        final patientName = snapshot.data?.name ?? 'Loading...';
        final initial = patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: appt.isRescheduleRequested
                  ? AppTheme.statusRescheduleText.withAlpha(100)
                  : AppTheme.borderGrey,
            ),
            boxShadow: AppTheme.softShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Avatar, Patient name, StatusBadge
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryNavy.withAlpha(25),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppTheme.primaryNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${appt.date} • ${appt.time} • ${appt.type}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: appt.status),
                ],
              ),

              // Reason
              if (appt.reason != null && appt.reason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason: ${appt.reason}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.slateDark),
                ),
              ],

              // Risk chip & response info
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (appt.riskScore != null || appt.riskLevel != null)
                    RiskChip(
                      riskScore: appt.riskScore,
                      riskLevel: appt.riskLevel,
                      riskFactors: appt.riskFactors,
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Response: ',
                        style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                      ),
                      StatusBadge(status: appt.confirmationStatus, fontSize: 11),
                    ],
                  ),
                ],
              ),

              // Reschedule Request Callout Banner
              if (appt.isRescheduleRequested) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.statusRescheduleBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.statusRescheduleText.withAlpha(70)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat, size: 18, color: AppTheme.statusRescheduleText),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Patient requested reschedule via WhatsApp',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.statusRescheduleText,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => _openSlotPickerModal(appt),
                        child: const Text(
                          'Pick New Slot',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.statusRescheduleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (appt.status != 'Completed' && appt.status != 'Cancelled') ...[
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      onPressed: () {
                        _appointmentService.updateAppointmentStatus(
                          appointmentId: appt.id,
                          status: 'Completed',
                        );
                      },
                      label: const Text('Complete'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.statusConfirmedText,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      onPressed: () {
                        _appointmentService.updateAppointmentStatus(
                          appointmentId: appt.id,
                          status: 'Missed',
                        );
                      },
                      label: const Text('Missed'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.statusMissedText,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      onPressed: () => _openSlotPickerModal(appt),
                      label: const Text('Reschedule'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.slateMuted),
                    tooltip: 'Delete Appointment',
                    onPressed: () => _confirmDeleteAppointment(appt),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- SLOT PICKER MODAL ---
  void _openSlotPickerModal(AppointmentModel appt) {
    DateTime pickedDate = DateTime.tryParse(appt.date) ?? DateTime.now();
    String selectedSlot = '10:00 AM';

    const defaultSlots = [
      '09:00 AM',
      '09:30 AM',
      '10:00 AM',
      '10:30 AM',
      '11:00 AM',
      '11:30 AM',
      '02:00 PM',
      '02:30 PM',
      '03:00 PM',
      '04:00 PM',
      '04:30 PM',
      '05:00 PM',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pick Reschedule Slot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a new date and available slot for the patient.',
                style: TextStyle(fontSize: 13, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 16),

              // Date Picker trigger
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.borderGrey),
                ),
                leading: const Icon(Icons.calendar_today, color: AppTheme.primaryTeal),
                title: Text(
                  'Date: ${DateUtilsHelper.formatDisplayDate(pickedDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final newDate = await showDatePicker(
                    context: modalCtx,
                    initialDate: pickedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (newDate != null) {
                    setModalState(() => pickedDate = newDate);
                  }
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Available Slots',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slateDark),
              ),
              const SizedBox(height: 10),

              // Slots grid / chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: defaultSlots.map((slot) {
                  final isSelected = selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryTeal,
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.slateDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => selectedSlot = slot);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final newDateStr = DateUtilsHelper.formatStorageDate(pickedDate);
                  await _appointmentService.rescheduleAppointment(
                    appointmentId: appt.id,
                    newDate: newDateStr,
                    newTime: selectedSlot,
                  );
                  if (modalCtx.mounted) {
                    Navigator.pop(modalCtx);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Appointment rescheduled to $newDateStr at $selectedSlot'),
                        backgroundColor: AppTheme.statusConfirmedText,
                      ),
                    );
                  }
                },
                child: const Text('Confirm New Slot', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAppointment(AppointmentModel appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: const Text('Are you sure you want to permanently remove this scheduled visit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.statusMissedText),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _appointmentService.deleteAppointment(appt.id);
    }
  }
}
