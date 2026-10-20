import 'package:flutter/material.dart';
import '../../../models/treatment_plan_model.dart';
import '../../../services/treatment_plan_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../widgets/treatment_plan_stepper.dart';

class TreatmentPlanDetailScreen extends StatefulWidget {
  final TreatmentPlanModel plan;

  const TreatmentPlanDetailScreen({super.key, required this.plan});

  @override
  State<TreatmentPlanDetailScreen> createState() => _TreatmentPlanDetailScreenState();
}

class _TreatmentPlanDetailScreenState extends State<TreatmentPlanDetailScreen> {
  final _planService = TreatmentPlanService();
  late TreatmentPlanModel _currentPlan;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
  }

  Future<void> _handleMarkStageDone(TreatmentPlanStageModel stage) async {
    final noteController = TextEditingController();
    final dateController = TextEditingController(
      text: DateTime.now().add(const Duration(days: 7)).toString().split(' ')[0],
    );

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Complete Stage ${stage.order}: ${stage.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mark this stage as completed and propose appointment date for the next stage.',
                style: TextStyle(fontSize: 13, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: dateController,
                decoration: InputDecoration(
                  labelText: 'Proposed Next Stage Date (YYYY-MM-DD)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        dateController.text = picked.toString().split(' ')[0];
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Doctor Clinical Notes (optional)',
                  hintText: 'e.g. Canals obturated, patient advised soft diet.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm & Complete'),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    setState(() => _isLoading = true);

    try {
      final res = await _planService.completeStage(
        planId: _currentPlan.id,
        stageOrder: stage.order,
        customNextDate: dateController.text.trim(),
        notes: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
      );

      final planMap = res['plan'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          if (planMap != null) {
            _currentPlan = TreatmentPlanModel.fromMap(planMap, _currentPlan.id);
          }
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stage ${stage.order} completed! Next stage scheduled.'),
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
  }

  Future<void> _handleSkipStage(TreatmentPlanStageModel stage) async {
    setState(() => _isLoading = true);
    try {
      final res = await _planService.skipStage(
        planId: _currentPlan.id,
        stageOrder: stage.order,
        reason: 'Clinically skipped by doctor',
      );
      final planMap = res['plan'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          if (planMap != null) {
            _currentPlan = TreatmentPlanModel.fromMap(planMap, _currentPlan.id);
          }
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stage ${stage.order} skipped.')),
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
  }

  @override
  Widget build(BuildContext context) {
    final stages = _currentPlan.stages;
    final completedCount = stages.where((s) => s.status == 'done').length;
    final totalCount = stages.length;
    final progressFraction = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPlan.title),
        actions: [
          StatusBadge(status: _currentPlan.status.toUpperCase()),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress summary card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderGrey),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Overall Progress: $completedCount of $totalCount Stages',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            Text(
                              '${(progressFraction * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            minHeight: 10,
                            backgroundColor: AppTheme.borderGrey,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                          ),
                        ),
                        if (_currentPlan.status == 'at_risk') ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.statusMissedBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppTheme.statusMissedText, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Plan at risk: A stage appointment was missed. Patient added to clinical recall list.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.statusMissedText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Clinical Treatment Stages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TreatmentPlanStepper(
                    stages: stages,
                    onMarkDone: _handleMarkStageDone,
                    onSkip: _handleSkipStage,
                  ),
                ],
              ),
            ),
    );
  }
}
