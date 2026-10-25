import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import '../../../models/patient_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';

import '../../../services/comms_sender_service.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _patientService = PatientService();
  final _commsService = CommsSenderService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctorId = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Patient',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPatientScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceWhite,
            child: TextField(
              style: const TextStyle(color: AppTheme.slateDark, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search patients by name, phone, or email...',
                prefixIcon: Icon(Icons.search, color: AppTheme.slateMuted),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const Divider(),

          // Patients List Stream
          Expanded(
            child: StreamBuilder<List<PatientModel>>(
              stream: _patientService.streamPatients(doctorId, searchQuery: _searchQuery),
              builder: (context, snapshot) {
                if (snapshot.data == null && snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Notice: ${snapshot.error}'));
                }

                final patients = snapshot.data ?? [];

                if (patients.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.people_outline,
                    title: _searchQuery.isEmpty ? 'No Patients Added Yet' : 'No Matching Patients',
                    description: _searchQuery.isEmpty
                      ? 'Add your first patient to begin tracking follow-ups and prescriptions.'
                      : 'Try a different search term or add a new patient.',
                    actionText: 'Add Patient',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddPatientScreen()),
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
                          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.primaryNavy,
                          child: Text(
                            patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          patient.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (patient.age != null) '${patient.age} yrs',
                                if (patient.phone != null) patient.phone!,
                                if (patient.email != null) patient.email!,
                              ].join(' • '),
                              style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (patient.phone != null && patient.phone!.isNotEmpty) ...[
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                icon: const Icon(Icons.sms_outlined, color: AppTheme.primaryBlue),
                                tooltip: 'Send SMS',
                                onPressed: () => _commsService.openMessageComposerDialog(
                                  context: context,
                                  doctorId: doctorId,
                                  patientId: patient.id,
                                  patientName: patient.name,
                                  initialPhone: patient.phone,
                                  initialEmail: patient.email,
                                  initialChannel: 'sms',
                                  defaultMessage: 'Hello ${patient.name}, greeting from CareTrack Dental Clinic!',
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
                                  patientId: patient.id,
                                  patientName: patient.name,
                                  initialPhone: patient.phone,
                                  initialEmail: patient.email,
                                  initialChannel: 'whatsapp',
                                  defaultMessage: 'Hello ${patient.name}, greeting from CareTrack Dental Clinic!',
                                ),
                              ),
                            ],
                            if (patient.email != null && patient.email!.isNotEmpty)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                icon: const Icon(Icons.email_outlined, color: Color(0xFF6366F1)),
                                tooltip: 'Send Email',
                                onPressed: () => _commsService.openMessageComposerDialog(
                                  context: context,
                                  doctorId: doctorId,
                                  patientId: patient.id,
                                  patientName: patient.name,
                                  initialPhone: patient.phone,
                                  initialEmail: patient.email,
                                  initialChannel: 'email',
                                  defaultSubject: 'CareTrack Dental Clinic - Patient Care Update',
                                  defaultMessage: 'Dear ${patient.name},\n\nYour patient care record is active in CareTrack.\n\nBest regards,\nCareTrack Team',
                                ),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.slateMuted),
                              onSelected: (val) async {
                                if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Patient?'),
                                      content: Text('Permanently delete ${patient.name}?'),
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
                                    await _patientService.deletePatient(patient.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Patient ${patient.name} deleted.'),
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
                          MaterialPageRoute(
                            builder: (_) => PatientDetailScreen(patient: patient),
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
