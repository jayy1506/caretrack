import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/demo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';

class DemoSettingsScreen extends StatelessWidget {
  const DemoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demoService = Provider.of<DemoService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo / Test Reminder Engine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent Dev Warning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.statusWarningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.statusWarning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science_outlined, color: AppTheme.statusWarning, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Development & Demonstration Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'In production, reminders are sent 24 hours before an appointment. In Demo Mode, you can test reminders at short intervals (1, 5, or 10 minutes) for instant demonstration.',
                          style: TextStyle(fontSize: 12, color: AppTheme.slateDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Demo Mode Switch Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Demo Mode',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Override standard 24h reminder window',
                              style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                            ),
                          ],
                        ),
                        Switch(
                          value: demoService.isDemoModeEnabled,
                          activeThumbColor: AppTheme.primaryNavy,
                          onChanged: (val) => demoService.toggleDemoMode(val),
                        ),
                      ],
                    ),
                    if (demoService.isDemoModeEnabled) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Select Test Reminder Offset:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildOffsetChip(context, demoService, 1, '1 Minute'),
                          const SizedBox(width: 8),
                          _buildOffsetChip(context, demoService, 5, '5 Minutes'),
                          const SizedBox(width: 8),
                          _buildOffsetChip(context, demoService, 10, '10 Minutes'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Demonstration Instructions Card
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to run a live demonstration:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text('1. Create an appointment scheduled for Current Time + 5 minutes.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('2. Ensure Demo Mode is ON with 5 Minutes offset.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('3. Tap "Trigger Reminder Check Now" below.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('4. Check Patient Communication History tab for real email/SMS logs.', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Trigger Button
            CustomButton(
              text: 'Trigger Reminder Check Now',
              isLoading: demoService.isRunningCheck,
              icon: Icons.play_arrow,
              onPressed: demoService.isDemoModeEnabled
                  ? () async {
                      try {
                        await demoService.triggerDemoCheck();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo reminder engine evaluation complete.'),
                              backgroundColor: AppTheme.statusSuccess,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.statusDanger),
                          );
                        }
                      }
                    }
                  : null,
            ),

            if (demoService.lastCheckResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Text(
                  'Result: ${demoService.lastCheckResult}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOffsetChip(BuildContext context, DemoService service, int minutes, String label) {
    final isSelected = service.demoOffsetMinutes == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryNavy,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.slateDark,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          service.setDemoOffset(minutes);
        }
      },
    );
  }
}
