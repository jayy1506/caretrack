import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/patient_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import '../../../services/appointment_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class AddAppointmentScreen extends StatefulWidget {
  final PatientModel? preselectedPatient;

  const AddAppointmentScreen({super.key, this.preselectedPatient});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appointmentService = AppointmentService();
  final _patientService = PatientService();

  PatientModel? _selectedPatient;
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _appointmentTime = const TimeOfDay(hour: 10, minute: 0);
  String _appointmentType = 'Consultation'; // 'Consultation' | 'Follow-up'
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.preselectedPatient;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitAppointment() async {
    if (_selectedPatient == null) {
      setState(() => _errorMessage = 'Please select a patient.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final doctorId = auth.currentUser?.uid ?? 'doc_01';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateStr = DateUtilsHelper.formatStorageDate(_appointmentDate);
      final hour = _appointmentTime.hourOfPeriod == 0 ? 12 : _appointmentTime.hourOfPeriod;
      final minute = _appointmentTime.minute.toString().padLeft(2, '0');
      final period = _appointmentTime.period == DayPeriod.am ? 'AM' : 'PM';
      final timeStr = '$hour:$minute $period';

      await _appointmentService.createAppointment(
        doctorId: doctorId,
        patientId: _selectedPatient!.id,
        date: dateStr,
        time: timeStr,
        type: _appointmentType,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final contactInfo = [
          if (_selectedPatient!.phone != null && _selectedPatient!.phone!.isNotEmpty) 'SMS to ${_selectedPatient!.phone}',
          if (_selectedPatient!.email != null && _selectedPatient!.email!.isNotEmpty) 'Email to ${_selectedPatient!.email}',
        ].join(' & ');
        final msg = contactInfo.isNotEmpty
            ? 'Appointment scheduled with ${_selectedPatient!.name} on $dateStr at $timeStr. Confirmation $contactInfo sent successfully!'
            : 'Appointment scheduled with ${_selectedPatient!.name} on $dateStr at $timeStr.';

        Navigator.pop(context, true);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppTheme.statusSuccess,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create appointment: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPatientPickerModal(BuildContext context, List<PatientModel> patients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = patients.where((p) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  (p.phone != null && p.phone!.contains(q)) ||
                  (p.email != null && p.email!.toLowerCase().contains(q));
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Patient',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slateDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search patient by name, mobile, email...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.slateMuted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() => query = val.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_off_outlined, size: 40, color: AppTheme.slateMuted),
                                const SizedBox(height: 8),
                                Text(
                                  query.isEmpty ? 'No registered patients found.' : 'No matching patient found.',
                                  style: const TextStyle(color: AppTheme.slateMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final p = filtered[i];
                              final isSelected = _selectedPatient?.id == p.id;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? AppTheme.primaryNavy : const Color(0xFFEFF6FF),
                                  foregroundColor: isSelected ? Colors.white : AppTheme.primaryNavy,
                                  child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P'),
                                ),
                                title: Text(
                                  p.name,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                subtitle: Text(
                                  [
                                    if (p.phone != null && p.phone!.isNotEmpty) '📱 ${p.phone}',
                                    if (p.email != null && p.email!.isNotEmpty) '✉️ ${p.email}',
                                  ].join('   '),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slateMedium),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppTheme.statusSuccess)
                                    : const Icon(Icons.chevron_right, color: AppTheme.slateMuted),
                                onTap: () {
                                  setState(() => _selectedPatient = p);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctorId = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Appointment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusDangerBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusDanger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.statusDanger, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Patient Selector
              if (widget.preselectedPatient == null) ...[
                const Text('Select Patient *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slateDark)),
                const SizedBox(height: 6),
                StreamBuilder<List<PatientModel>>(
                  stream: _patientService.streamPatients(doctorId),
                  builder: (context, snapshot) {
                    final rawPatients = snapshot.data ?? [];
                    final uniqueMap = <String, PatientModel>{};
                    for (final p in rawPatients) {
                      if (p.id.isNotEmpty) uniqueMap[p.id] = p;
                    }
                    final patients = uniqueMap.values.toList();

                    if (_selectedPatient != null) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryNavy,
                              radius: 18,
                              child: Text(
                                _selectedPatient!.name.isNotEmpty ? _selectedPatient!.name[0].toUpperCase() : 'P',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedPatient!.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.slateDark,
                                    ),
                                  ),
                                  if (_selectedPatient!.phone != null || _selectedPatient!.email != null)
                                    Text(
                                      [
                                        if (_selectedPatient!.phone != null) _selectedPatient!.phone,
                                        if (_selectedPatient!.email != null) _selectedPatient!.email,
                                      ].join(' • '),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.slateMedium),
                                    ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showPatientPickerModal(context, patients),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      );
                    }

                    return InkWell(
                      onTap: () => _showPatientPickerModal(context, patients),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderGrey),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_search_outlined, color: AppTheme.primaryBlue, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Tap to select a registered patient...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppTheme.slateMedium,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppTheme.slateDark),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: AppTheme.primaryNavy),
                        const SizedBox(width: 10),
                        Text(
                          'Patient: ${widget.preselectedPatient!.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Routine Checkup Presets (1, 2, or 3 Months)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_repeat, color: Color(0xFF16A34A), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '⚡ Quick Routine Checkup (1, 2, or 3 Months):',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF15803D),
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _appointmentType = 'Routine Checkup';
                                _appointmentDate = DateTime.now().add(const Duration(days: 30));
                                _reasonController.text = 'Routine Dental Examination & Cleaning (1-Month Recall)';
                              });
                            },
                            child: const Text('1 Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF15803D),
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _appointmentType = 'Routine Checkup';
                                _appointmentDate = DateTime.now().add(const Duration(days: 60));
                                _reasonController.text = 'Routine Dental Examination & Cleaning (2-Month Recall)';
                              });
                            },
                            child: const Text('2 Months', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF15803D),
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _appointmentType = 'Routine Checkup';
                                _appointmentDate = DateTime.now().add(const Duration(days: 90));
                                _reasonController.text = 'Routine Dental Examination & Cleaning (3-Month Recall)';
                              });
                            },
                            child: const Text('3 Months', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Appointment Type
              const Text('Appointment Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slateDark)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _appointmentType = 'Consultation'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _appointmentType == 'Consultation' ? const Color(0xFFEFF6FF) : Colors.transparent,
                          border: Border.all(
                            color: _appointmentType == 'Consultation' ? AppTheme.primaryNavy : AppTheme.borderGrey,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Consultation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _appointmentType == 'Consultation' ? AppTheme.primaryNavy : AppTheme.slateDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _appointmentType = 'Follow-up'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _appointmentType == 'Follow-up' ? const Color(0xFFEFF6FF) : Colors.transparent,
                          border: Border.all(
                            color: _appointmentType == 'Follow-up' ? AppTheme.primaryNavy : AppTheme.borderGrey,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Follow-up',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _appointmentType == 'Follow-up' ? AppTheme.primaryNavy : AppTheme.slateDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _appointmentType = 'Routine Checkup'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _appointmentType == 'Routine Checkup' ? const Color(0xFFEFF6FF) : Colors.transparent,
                          border: Border.all(
                            color: _appointmentType == 'Routine Checkup' ? AppTheme.primaryNavy : AppTheme.borderGrey,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Routine',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _appointmentType == 'Routine Checkup' ? AppTheme.primaryNavy : AppTheme.slateDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Time pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(DateUtilsHelper.formatDisplayDate(_appointmentDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _appointmentDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _appointmentDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_appointmentTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _appointmentTime,
                        );
                        if (picked != null) setState(() => _appointmentTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reason
              CustomTextField(
                controller: _reasonController,
                label: 'Reason for Visit',
                hint: 'e.g. Routine check-up, Tooth pain evaluation',
              ),
              const SizedBox(height: 16),

              // Notes
              CustomTextField(
                controller: _notesController,
                label: 'Internal Notes',
                hint: 'Optional notes for clinic records',
                maxLines: 2,
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: 'Schedule & Send Confirmation',
                onPressed: _submitAppointment,
                isLoading: _isLoading,
                icon: Icons.calendar_month,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
