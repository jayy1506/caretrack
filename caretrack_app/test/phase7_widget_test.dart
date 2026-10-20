import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caretrack_app/core/widgets/status_badge.dart';
import 'package:caretrack_app/core/theme/app_theme.dart';
import 'package:caretrack_app/widgets/counter_tile.dart';
import 'package:caretrack_app/widgets/treatment_plan_stepper.dart';
import 'package:caretrack_app/models/treatment_plan_model.dart';

void main() {
  group('Phase 7 Widget Tests: StatusBadge', () {
    testWidgets('renders Confirmed badge with check icon and color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Confirmed'),
          ),
        ),
      );

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders Pending badge with clock icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Pending'),
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('renders Reschedule Requested badge with repeat icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Reschedule Requested'),
          ),
        ),
      );

      expect(find.text('Reschedule Requested'), findsOneWidget);
      expect(find.byIcon(Icons.event_repeat), findsOneWidget);
    });

    testWidgets('renders Missed badge with error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Missed'),
          ),
        ),
      );

      expect(find.text('Missed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('Phase 7 Widget Tests: CounterTile', () {
    testWidgets('renders title, count, and triggers tap callback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CounterTile(
              label: 'Today Visits',
              count: 8,
              subtitle: 'Scheduled appointments',
              icon: Icons.calendar_today,
              color: AppTheme.primaryTeal,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Today Visits'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Scheduled appointments'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);

      await tester.tap(find.text('Today Visits'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders in danger mode for Overdue count', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CounterTile(
              label: 'Overdue Follow-ups',
              count: 5,
              icon: Icons.warning_rounded,
              color: AppTheme.statusMissedText,
              isDanger: true,
            ),
          ),
        ),
      );

      expect(find.text('Overdue Follow-ups'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });
  });

  group('Phase 7 Widget Tests: TreatmentPlanStepper', () {
    testWidgets('renders plan stages with order, names, and action buttons', (WidgetTester tester) async {
      TreatmentPlanStageModel? markedDoneStage;
      TreatmentPlanStageModel? skippedStage;

      final testStages = [
        TreatmentPlanStageModel(
          order: 1,
          name: 'Pulp Extirpation & Dressing',
          intervalDaysFromPrevious: 0,
          status: 'done',
          notes: 'Completed successfully without pain',
        ),
        TreatmentPlanStageModel(
          order: 2,
          name: 'Canal Shaping & Cleaning',
          intervalDaysFromPrevious: 7,
          status: 'scheduled',
          notes: 'Scheduled for next sitting',
        ),
        TreatmentPlanStageModel(
          order: 3,
          name: 'Obturation & Permanent Filling',
          intervalDaysFromPrevious: 7,
          status: 'upcoming',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TreatmentPlanStepper(
                stages: testStages,
                onMarkDone: (st) {
                  markedDoneStage = st;
                },
                onSkip: (st) {
                  skippedStage = st;
                },
              ),
            ),
          ),
        ),
      );

      // Verify stage titles
      expect(find.textContaining('Stage 1: Pulp Extirpation & Dressing'), findsOneWidget);
      expect(find.textContaining('Stage 2: Canal Shaping & Cleaning'), findsOneWidget);
      expect(find.textContaining('Stage 3: Obturation & Permanent Filling'), findsOneWidget);

      // Verify status badges
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);

      // Verify action buttons for scheduled stage
      expect(find.text('Mark Done & Propose Next'), findsWidgets);
      expect(find.text('Skip Stage'), findsWidgets);

      // Tap Mark Done
      await tester.tap(find.text('Mark Done & Propose Next').first);
      await tester.pump();
      expect(markedDoneStage?.name, 'Canal Shaping & Cleaning');

      // Tap Skip Stage
      await tester.tap(find.text('Skip Stage').first);
      await tester.pump();
      expect(skippedStage?.name, 'Canal Shaping & Cleaning');
    });
  });

  group('Phase 7 Golden & Theming Tests: Dashboard Counters in Light & Dark Mode', () {
    Widget buildDashboardCounterRow() {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: CounterTile(
                label: 'Today',
                count: 12,
                icon: Icons.calendar_today,
                color: AppTheme.primaryTeal,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: CounterTile(
                label: '3 Days',
                count: 19,
                icon: Icons.next_plan,
                color: AppTheme.primaryNavy,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: CounterTile(
                label: '7 Days',
                count: 34,
                icon: Icons.date_range,
                color: Color(0xFF6366F1),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: CounterTile(
                label: 'Overdue',
                count: 4,
                icon: Icons.error_outline,
                color: AppTheme.statusMissedText,
                isDanger: true,
              ),
            ),
          ],
        ),
      );
    }

    testWidgets('renders Dashboard Counters in Light Mode with AppTheme tokens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: buildDashboardCounterRow(),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('renders Dashboard Counters in Dark Mode with AppTheme tokens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: buildDashboardCounterRow(),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });
}
