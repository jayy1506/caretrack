import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caretrack_app/core/widgets/status_badge.dart';

void main() {
  group('StatusBadge Widget Tests', () {
    testWidgets('renders Confirmed status badge correctly', (WidgetTester tester) async {
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

    testWidgets('renders Pending status badge correctly', (WidgetTester tester) async {
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

    testWidgets('renders Missed status badge correctly', (WidgetTester tester) async {
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

    testWidgets('renders Reschedule Requested status badge correctly', (WidgetTester tester) async {
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
  });
}
