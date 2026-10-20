import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  final String clinicId;

  const AnalyticsScreen({super.key, this.clinicId = 'default-clinic'});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Performance & Analytics'),
        actions: [
          DropdownButton<int>(
            value: _selectedDays,
            dropdownColor: AppTheme.primaryNavy,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: const [
              DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
              DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
              DropdownMenuItem(value: 90, child: Text('Last 90 Days')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedDays = val);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Summary Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Confirmation Rate',
                    value: '88.4%',
                    subtitle: '+4.2% vs last period',
                    color: AppTheme.statusConfirmedText,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Missed / No-Show',
                    value: '6.8%',
                    subtitle: '-3.1% reduction',
                    color: AppTheme.statusMissedText,
                    icon: Icons.trending_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Recall Conversion',
                    value: '42.6%',
                    subtitle: 'Patients rebooked',
                    color: AppTheme.primaryTeal,
                    icon: Icons.sync,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Plan Completion',
                    value: '91.2%',
                    subtitle: 'All stages done',
                    color: const Color(0xFF6366F1),
                    icon: Icons.task_alt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Reminders by Channel Breakdown
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
                  const Text(
                    'Reminders Dispatched by Channel',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 14),
                  _buildChannelBar('WhatsApp (92% open rate)', 0.74, const Color(0xFF10B981), '74%'),
                  const SizedBox(height: 10),
                  _buildChannelBar('SMS (Transactional)', 0.18, const Color(0xFF3B82F6), '18%'),
                  const SizedBox(height: 10),
                  _buildChannelBar('Email (Clinical Summary)', 0.08, const Color(0xFF6366F1), '8%'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Treatment Retention Summary
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
                  const Text(
                    'Retention & Stage Follow-Through',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Measures multi-visit patient return rates across Root Canal, Orthodontics, and Routine Scaling cohorts.',
                    style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                  ),
                  const SizedBox(height: 14),
                  _buildChannelBar('Root Canal (3 sittings)', 0.94, AppTheme.primaryTeal, '94% completed'),
                  const SizedBox(height: 10),
                  _buildChannelBar('Orthodontic Checkups', 0.88, const Color(0xFF0284C7), '88% completed'),
                  const SizedBox(height: 10),
                  _buildChannelBar('6-Month Dental Scaling', 0.76, const Color(0xFFD97706), '76% rebooked'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted, fontWeight: FontWeight.w600)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBar(String label, double fraction, Color color, String pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(pct, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppTheme.borderGrey,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
