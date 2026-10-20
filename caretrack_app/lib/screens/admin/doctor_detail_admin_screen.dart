import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_service.dart';
import '../../models/user_model.dart';
import '../../models/patient_model.dart';
import '../../models/appointment_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/utils/date_formatter.dart';
import '../doctor/patients/patient_detail_screen.dart';

class DoctorDetailAdminScreen extends StatefulWidget {
  final UserModel doctor;

  const DoctorDetailAdminScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailAdminScreen> createState() => _DoctorDetailAdminScreenState();
}

class _DoctorDetailAdminScreenState extends State<DoctorDetailAdminScreen> with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  late TabController _tabController;
  late UserModel _currentDoctor;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentDoctor = widget.doctor;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleAdminRole() async {
    final oldRole = _currentDoctor.role;
    final newRole = _currentDoctor.isAdmin ? 'doctor' : 'admin';

    setState(() {
      _isUpdating = true;
      _currentDoctor = UserModel(
        uid: _currentDoctor.uid,
        name: _currentDoctor.name,
        email: _currentDoctor.email,
        phone: _currentDoctor.phone,
        role: newRole,
        active: _currentDoctor.active,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newRole == 'admin'
              ? '${_currentDoctor.name} has been granted Admin Access.'
              : 'Admin access revoked for ${_currentDoctor.name}.',
        ),
        backgroundColor: AppTheme.statusSuccess,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await _adminService.updateUserRole(
        userId: _currentDoctor.uid,
        newRole: newRole,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentDoctor = UserModel(
            uid: _currentDoctor.uid,
            name: _currentDoctor.name,
            email: _currentDoctor.email,
            phone: _currentDoctor.phone,
            role: oldRole,
            active: _currentDoctor.active,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _toggleStatus() async {
    final oldStatus = _currentDoctor.active;
    final newStatus = !_currentDoctor.active;

    setState(() {
      _isUpdating = true;
      _currentDoctor = UserModel(
        uid: _currentDoctor.uid,
        name: _currentDoctor.name,
        email: _currentDoctor.email,
        phone: _currentDoctor.phone,
        role: _currentDoctor.role,
        active: newStatus,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_currentDoctor.name} account is now ${newStatus ? 'Active' : 'Disabled'}.',
        ),
        backgroundColor: newStatus ? AppTheme.statusSuccess : AppTheme.statusDanger,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await _adminService.toggleDoctorStatus(
        doctorId: _currentDoctor.uid,
        active: newStatus,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentDoctor = UserModel(
            uid: _currentDoctor.uid,
            name: _currentDoctor.name,
            email: _currentDoctor.email,
            phone: _currentDoctor.phone,
            role: _currentDoctor.role,
            active: oldStatus,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_currentDoctor.name),
      ),
      body: Column(
        children: [
          // Doctor Header Card
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primaryNavy,
                      child: Text(
                        _currentDoctor.name.isNotEmpty ? _currentDoctor.name[0].toUpperCase() : 'D',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _currentDoctor.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.slateDark,
                                  ),
                                ),
                              ),
                              StatusBadge(status: _currentDoctor.active ? 'Active' : 'Disabled'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDoctor.email,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.slateMuted),
                          ),
                          if (_currentDoctor.phone != null && _currentDoctor.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _currentDoctor.phone!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.slateMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Admin Controls Row
                Row(
                  children: [
                    // Role Pill & Toggle Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentDoctor.isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentDoctor.isAdmin ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentDoctor.isAdmin ? Icons.admin_panel_settings : Icons.medical_services_outlined,
                            size: 16,
                            color: _currentDoctor.isAdmin ? AppTheme.primaryBlue : AppTheme.slateDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentDoctor.isAdmin ? 'Role: Clinic Admin' : 'Role: Doctor',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _currentDoctor.isAdmin ? AppTheme.primaryBlue : AppTheme.slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Grant/Revoke Admin Action
                    OutlinedButton.icon(
                      onPressed: _isUpdating ? null : _toggleAdminRole,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: _currentDoctor.isAdmin ? AppTheme.statusDanger : AppTheme.primaryNavy),
                        foregroundColor: _currentDoctor.isAdmin ? AppTheme.statusDanger : AppTheme.primaryNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        _currentDoctor.isAdmin ? Icons.remove_moderator : Icons.add_moderator,
                        size: 15,
                      ),
                      label: Text(
                        _currentDoctor.isAdmin ? 'Revoke Admin' : 'Grant Admin Access',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),

                    // Active Toggle
                    IconButton(
                      onPressed: _isUpdating ? null : _toggleStatus,
                      icon: Icon(
                        _currentDoctor.active ? Icons.block : Icons.check_circle_outline,
                        color: _currentDoctor.active ? AppTheme.statusDanger : AppTheme.statusSuccess,
                      ),
                      tooltip: _currentDoctor.active ? 'Disable Account' : 'Enable Account',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar for Patients vs Visits
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryNavy,
              unselectedLabelColor: AppTheme.slateMuted,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              indicatorColor: AppTheme.primaryNavy,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Registered Patients'),
                Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Scheduled Visits'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPatientsTab(),
                _buildAppointmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTab() {
    return StreamBuilder<List<PatientModel>>(
      stream: _adminService.streamDoctorPatients(_currentDoctor.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final patients = snapshot.data ?? [];

        if (patients.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined, size: 48, color: AppTheme.slateMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No Patients Registered Yet',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.slateDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Patients added by ${_currentDoctor.name} will appear here.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.slateMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final patient = patients[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: AppTheme.primaryNavy,
                  child: Text(
                    patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  patient.name,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (patient.phone != null && patient.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: AppTheme.slateMuted),
                          const SizedBox(width: 4),
                          Text(patient.phone!, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.slateMuted)),
                        ],
                      ),
                    ],
                    if (patient.email != null && patient.email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 12, color: AppTheme.slateMuted),
                          const SizedBox(width: 4),
                          Text(patient.email!, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.slateMuted)),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.slateMuted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentsTab() {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _adminService.streamDoctorAppointments(_currentDoctor.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 48, color: AppTheme.slateMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No Scheduled Appointments',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.slateDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Follow-ups and consultations will appear in this feed.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.slateMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final appt = appointments[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            appt.time,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          Text(
                            DateUtilsHelper.formatDisplayDate(DateUtilsHelper.parseStorageDate(appt.date)),
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.slateMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt.type,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (appt.reason != null && appt.reason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              appt.reason!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.slateMedium),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusBadge(status: appt.confirmationStatus),
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
