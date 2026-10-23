import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caretrack_app/core/theme/app_theme.dart';
import 'package:caretrack_app/core/widgets/status_badge.dart';
import 'package:caretrack_app/core/widgets/bottom_nav_pill.dart';
import 'package:caretrack_app/widgets/counter_tile.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Phase 5 Frontend: AppTheme Color & Design System Tokens', () {
    testWidgets('AppTheme defines required M3 color palette and radii', (tester) async {
      expect(AppTheme.primaryNavy, const Color(0xFF0F2A47));
      expect(AppTheme.primaryTeal, const Color(0xFF0F766E));
      expect(AppTheme.mintAccent, const Color(0xFF2DD4BF));
      expect(AppTheme.backgroundGrey, const Color(0xFFF3F6FA));
      expect(AppTheme.cardRadius, const BorderRadius.all(Radius.circular(18)));

      final light = AppTheme.lightTheme;
      expect(light.useMaterial3, isTrue);
      expect(light.scaffoldBackgroundColor, AppTheme.backgroundGrey);
      expect(light.colorScheme.primary, AppTheme.primaryTeal);
      expect(light.colorScheme.secondary, AppTheme.mintAccent);

      final dark = AppTheme.darkTheme;
      expect(dark.useMaterial3, isTrue);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.primary, AppTheme.mintAccent);
    });
  });

  group('Phase 5 Frontend: StatusBadge Redesign', () {
    testWidgets('renders redesigned Confirmed badge with pill border and check icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Confirmed'),
          ),
        ),
      );

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.statusConfirmedBg);
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('renders redesigned Pending badge with clock icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Pending'),
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.statusPendingBg);
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('renders redesigned Reschedule Requested badge with repeat icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Reschedule Requested'),
          ),
        ),
      );

      expect(find.text('Reschedule Requested'), findsOneWidget);
      expect(find.byIcon(Icons.event_repeat), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.statusRescheduleBg);
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('renders redesigned Missed badge in danger colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'Missed'),
          ),
        ),
      );

      expect(find.text('Missed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.statusMissedBg);
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });
  });

  group('Phase 5 Frontend: BottomNavPill Widget', () {
    testWidgets('renders all navigation items and handles tab switching', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: BottomNavPill(
                  currentIndex: selectedTab,
                  onTap: (idx) {
                    setState(() {
                      selectedTab = idx;
                    });
                  },
                  items: const [
                    BottomNavPillItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard,
                      label: 'Dashboard',
                    ),
                    BottomNavPillItem(
                      icon: Icons.people_outline,
                      activeIcon: Icons.people,
                      label: 'Patients',
                    ),
                    BottomNavPillItem(
                      icon: Icons.calendar_month_outlined,
                      activeIcon: Icons.calendar_month,
                      label: 'Visits',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);

      // Tap 'Patients' tab (index 1)
      await tester.tap(find.text('Patients'));
      await tester.pumpAndSettle();

      expect(selectedTab, 1);

      // Tap 'Visits' tab (index 2)
      await tester.tap(find.text('Visits'));
      await tester.pumpAndSettle();

      expect(selectedTab, 2);
    });
  });

  group('Phase 5 Frontend: Dashboard Counters in Light & Dark Mode', () {
    Widget buildDashboardCounterBar() {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: CounterTile(
                label: "Today's Visits",
                count: 14,
                icon: Icons.calendar_today,
                color: AppTheme.primaryTeal,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: CounterTile(
                label: 'Due in 3 Days',
                count: 8,
                icon: Icons.schedule,
                color: AppTheme.primaryNavy,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: CounterTile(
                label: 'Due in 7 Days',
                count: 22,
                icon: Icons.date_range,
                color: AppTheme.mintAccent,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: CounterTile(
                label: 'Overdue Recalls',
                count: 5,
                icon: Icons.warning_amber_rounded,
                color: AppTheme.statusMissedText,
                isDanger: true,
              ),
            ),
          ],
        ),
      );
    }

    testWidgets('renders Dashboard Counters in Light Mode with 18px radius cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: buildDashboardCounterBar(),
          ),
        ),
      );

      expect(find.text("Today's Visits"), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Due in 3 Days'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Due in 7 Days'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('Overdue Recalls'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify 18px radius on the container
      final firstTile = tester.widget<Container>(find.descendant(
        of: find.byType(CounterTile).first,
        matching: find.byType(Container).first,
      ));
      final decoration = firstTile.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));
    });

    testWidgets('renders Dashboard Counters in Dark Mode with dark theme tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: buildDashboardCounterBar(),
          ),
        ),
      );

      expect(find.text("Today's Visits"), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Due in 3 Days'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Due in 7 Days'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('Overdue Recalls'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
