import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import 'doctor_list_screen.dart';
import 'add_doctor_screen.dart';

import '../../services/offline_store.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final adminService = AdminService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: adminService.streamDoctors(),
        builder: (context, snapshot) {
          final doctors = snapshot.data ?? [];
          final activeDoctors = doctors.where((d) => d.active).length;
          final disabledDoctors = doctors.where((d) => !d.active).length;
          final totalPatients = OfflineStore().patients.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome card
                Card(
                  color: AppTheme.primaryNavy,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CareTrack Administration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Signed in as ${auth.currentUser?.email ?? "Admin"}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Statistics row
                const Text(
                  'Clinic Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slateDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Patients',
                        count: totalPatients.toString(),
                        color: const Color(0xFF6366F1),
                        icon: Icons.people_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Doctors',
                        count: doctors.length.toString(),
                        color: AppTheme.primaryNavy,
                        icon: Icons.medical_services_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Active Doctors',
                        count: activeDoctors.toString(),
                        color: AppTheme.statusSuccess,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Disabled',
                        count: disabledDoctors.toString(),
                        color: AppTheme.statusDanger,
                        icon: Icons.block,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Actions
                const Text(
                  'Management Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slateDark,
                  ),
                ),
                const SizedBox(height: 12),

                ListTile(
                  tileColor: AppTheme.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: AppTheme.borderGrey),
                  ),
                  leading: const Icon(Icons.person_add_outlined, color: AppTheme.primaryNavy),
                  title: const Text('Add New Doctor', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Create doctor credentials and assign clinic permissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
                  ),
                ),
                const SizedBox(height: 10),

                ListTile(
                  tileColor: AppTheme.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: AppTheme.borderGrey),
                  ),
                  leading: const Icon(Icons.people_outline, color: AppTheme.primaryNavy),
                  title: const Text('View Doctor Directory', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enable, disable, or inspect doctor profiles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorListScreen()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slateMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
