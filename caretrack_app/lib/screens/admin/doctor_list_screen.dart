import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state_view.dart';
import 'add_doctor_screen.dart';
import 'doctor_detail_admin_screen.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _adminService = AdminService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Doctors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Doctor',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceWhite,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by doctor name or email...',
                prefixIcon: Icon(Icons.search, color: AppTheme.slateMuted),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          const Divider(),

          // Doctors stream list
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _adminService.streamDoctors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading doctors: ${snapshot.error}'),
                  );
                }

                var doctors = snapshot.data ?? [];
                if (_searchQuery.isNotEmpty) {
                  doctors = doctors.where((d) =>
                    d.name.toLowerCase().contains(_searchQuery) ||
                    d.email.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (doctors.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.people_outline,
                    title: 'No Doctors Found',
                    description: 'Add a new doctor account to grant clinic access.',
                    actionText: 'Add Doctor',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = doctors[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailAdminScreen(doctor: doc),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                                foregroundColor: AppTheme.primaryNavy,
                                child: Text(
                                  doc.name.isNotEmpty ? doc.name[0].toUpperCase() : 'D',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppTheme.slateDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      doc.email,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.slateMuted,
                                      ),
                                    ),
                                    if (doc.phone != null && doc.phone!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        doc.phone!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.slateMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusBadge(
                                    status: doc.active ? 'Active' : 'Disabled',
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final newStatus = !doc.active;
                                      try {
                                        await _adminService.toggleDoctorStatus(
                                          doctorId: doc.uid,
                                          active: newStatus,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Doctor ${doc.name} has been ${newStatus ? 'enabled' : 'disabled'}.',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      doc.active ? 'Disable' : 'Enable',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: doc.active ? AppTheme.statusDanger : AppTheme.primaryNavy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: AppTheme.slateMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
