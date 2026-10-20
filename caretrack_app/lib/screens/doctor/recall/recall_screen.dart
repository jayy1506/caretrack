import 'package:flutter/material.dart';
import '../../../services/inbox_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';

class RecallScreen extends StatefulWidget {
  final String clinicId;

  const RecallScreen({super.key, this.clinicId = 'default-clinic'});

  @override
  State<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends State<RecallScreen> {
  final _inboxService = InboxService();
  final Set<String> _selectedPatientIds = {};
  int _monthsOverdue = 6;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Recall Campaigns'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by Months Overdue',
            initialValue: _monthsOverdue,
            onSelected: (val) => setState(() => _monthsOverdue = val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 3, child: Text('3+ Months Overdue')),
              const PopupMenuItem(value: 6, child: Text('6+ Months Overdue (Standard)')),
              const PopupMenuItem(value: 12, child: Text('12+ Months Overdue')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<RecallCandidate>>(
        future: _inboxService.getRecallCandidates(
          clinicId: widget.clinicId,
          monthsThreshold: _monthsOverdue,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final candidates = snapshot.data ?? [];

          if (candidates.isEmpty) {
            return const EmptyStateView(
              icon: Icons.check_circle_outline,
              title: 'All Patients Up to Date',
              description: 'No patients found due for clinical recall in this threshold.',
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Found ${candidates.length} recall candidates ($_monthsOverdue+ mos)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedPatientIds.length == candidates.length) {
                            _selectedPatientIds.clear();
                          } else {
                            _selectedPatientIds.addAll(candidates.map((c) => c.patientId));
                          }
                        });
                      },
                      child: Text(
                        _selectedPatientIds.length == candidates.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cand = candidates[index];
                    final isSelected = _selectedPatientIds.contains(cand.patientId);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTeal : AppTheme.borderGrey,
                          width: isSelected ? 1.8 : 1,
                        ),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        activeColor: AppTheme.primaryTeal,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedPatientIds.add(cand.patientId);
                            } else {
                              _selectedPatientIds.remove(cand.patientId);
                            }
                          });
                        },
                        title: Text(
                          cand.patientName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          '${cand.reason} • Last visit: ${cand.lastVisitDate ?? "None"}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(
                            cand.patientName.isNotEmpty ? cand.patientName[0].toUpperCase() : 'P',
                            style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selectedPatientIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.borderGrey)),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      'Launch Recall Campaign (${_selectedPatientIds.length} Patients)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isLoading ? null : () => _confirmAndLaunchCampaign(candidates),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _confirmAndLaunchCampaign(List<RecallCandidate> candidates) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Confirm Recall Broadcast'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to queue recall campaign notifications to ${_selectedPatientIds.length} patients.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Meta WhatsApp approved template will be used.\n• Patients without messaging consent are skipped automatically.\n• Patients messaged in the last 14 days are protected by anti-spam cooldown.',
                style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => _isLoading = true);
                try {
                  final campaign = await _inboxService.triggerCampaign(
                    clinicId: widget.clinicId,
                    name: 'Routine Dental Recall ($_monthsOverdue+ months)',
                    templateName: 'routine_checkup_recall',
                    patientIds: _selectedPatientIds.toList(),
                  );
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _selectedPatientIds.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Campaign sent: ${campaign.sentCount} sent (${campaign.skippedRecentCount} skipped by anti-spam).',
                        ),
                        backgroundColor: AppTheme.statusConfirmedText,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.statusMissedText),
                    );
                  }
                }
              },
              child: const Text('Confirm & Send'),
            ),
          ],
        );
      },
    );
  }
}
