import 'package:flutter/material.dart';
import '../models/treatment_plan_model.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/status_badge.dart';

class TreatmentPlanStepper extends StatelessWidget {
  final List<TreatmentPlanStageModel> stages;
  final ValueChanged<TreatmentPlanStageModel>? onMarkDone;
  final ValueChanged<TreatmentPlanStageModel>? onSkip;

  const TreatmentPlanStepper({
    super.key,
    required this.stages,
    this.onMarkDone,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No stages configured for this plan.',
            style: TextStyle(color: AppTheme.slateMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stages.length,
      itemBuilder: (context, index) {
        final stage = stages[index];
        final isLast = index == stages.length - 1;

        Color dotColor;
        IconData dotIcon;

        switch (stage.status) {
          case 'done':
            dotColor = AppTheme.statusConfirmedText;
            dotIcon = Icons.check;
            break;
          case 'scheduled':
            dotColor = AppTheme.primaryTeal;
            dotIcon = Icons.calendar_month;
            break;
          case 'skipped':
            dotColor = AppTheme.slateMuted;
            dotIcon = Icons.skip_next;
            break;
          case 'upcoming':
          default:
            dotColor = AppTheme.statusPendingText;
            dotIcon = Icons.circle_outlined;
            break;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator column
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: dotColor.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: dotColor, width: 2),
                    ),
                    child: Center(
                      child: Icon(dotIcon, size: 16, color: dotColor),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppTheme.borderGrey,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Stage details card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderGrey),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Stage ${stage.order}: ${stage.name}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slateDark,
                                ),
                              ),
                            ),
                            StatusBadge(status: stage.status.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stage.intervalDaysFromPrevious == 0
                            ? 'Initial consultation visit'
                            : 'Scheduled ~${stage.intervalDaysFromPrevious} days after previous stage',
                          style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                        ),
                        if (stage.notes != null && stage.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            stage.notes!,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (stage.status != 'done' && stage.status != 'skipped') ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (onSkip != null)
                                TextButton(
                                  onPressed: () => onSkip?.call(stage),
                                  child: const Text('Skip Stage', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12)),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: const Text('Mark Done & Propose Next', style: TextStyle(fontSize: 12)),
                                onPressed: () => onMarkDone?.call(stage),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
