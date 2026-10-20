import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caretrack_app/widgets/risk_chip.dart';
import 'package:caretrack_app/widgets/prescription_safety_banner.dart';
import 'package:caretrack_app/models/prescription_safety_warning.dart';

void main() {
  group('Phase 6 Widgets: RiskChip Tests', () {
    testWidgets('renders High Risk chip correctly with percentage and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiskChip(
              riskScore: 0.75,
              riskLevel: 'high',
              riskFactors: ['3 past missed appointments', 'Lead time > 14 days'],
            ),
          ),
        ),
      );

      expect(find.text('High Risk (75%)'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders Low Risk chip correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiskChip(
              riskScore: 0.12,
              riskLevel: 'low',
            ),
          ),
        ),
      );

      expect(find.text('Low Risk'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('Phase 6 Widgets: PrescriptionSafetyBanner Tests', () {
    testWidgets('renders safety check passed banner when no warnings', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrescriptionSafetyBanner(warnings: []),
          ),
        ),
      );

      expect(find.textContaining('Safety Check Passed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders clinical safety alert banner with override action when danger warning exists', (WidgetTester tester) async {
      String? overriddenReason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionSafetyBanner(
              warnings: [
                PrescriptionSafetyWarning(
                  type: 'allergy_conflict',
                  severity: 'danger',
                  medicineName: 'Amoxicillin 500mg',
                  conflictingItem: 'Penicillin',
                  message: 'ALLERGY WARNING: Patient allergic to penicillin.',
                  clinicalRationale: 'High risk of hypersensitivity or anaphylaxis.',
                ),
              ],
              onDoctorOverride: (reason) {
                overriddenReason = reason;
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('Clinical Safety Alert'), findsOneWidget);
      expect(find.textContaining('Patient allergic to penicillin'), findsOneWidget);
      expect(find.text('Doctor Override'), findsOneWidget);

      // Tap Doctor Override button
      await tester.tap(find.text('Doctor Override'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Doctor Override'), findsOneWidget);

      // Tap Confirm Override in dialog
      await tester.tap(find.text('Confirm Override'));
      await tester.pumpAndSettle();

      expect(overriddenReason, isNotNull);
    });
  });
}
