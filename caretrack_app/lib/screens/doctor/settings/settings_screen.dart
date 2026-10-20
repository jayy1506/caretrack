import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_service.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/custom_button.dart';
import 'demo_settings_screen.dart';
import '../../compliance/privacy_policy_screen.dart';
import '../../compliance/terms_of_service_screen.dart';
import '../../compliance/feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _adminService = AdminService();

  // Local state for editable clinic details
  String _clinicName = 'CareTrack Dental Clinic';
  String _clinicAddress = '101 Healthcare Blvd, Bandra West, Mumbai, MH';
  String _clinicPhone = '+91 98765 43210';
  final String _timezone = 'Asia/Kolkata (IST)';
  String _selectedLanguage = 'en';

  // Feature toggles
  bool _flagTreatmentPlans = true;
  bool _flagOnlineBooking = true;
  bool _flagTwoWayWhatsApp = true;
  bool _flagRecall = true;
  bool _flagMedicationReminders = true;
  bool _flagNoShowAI = true;
  bool _flagFaqAssistant = false;

  // Clinic Holidays
  final List<Map<String, String>> _holidays = [
    {'date': '2026-01-26', 'name': 'Republic Day'},
    {'date': '2026-08-15', 'name': 'Independence Day'},
    {'date': '2026-10-02', 'name': 'Gandhi Jayanti'},
    {'date': '2026-11-08', 'name': 'Diwali (Laxmi Pujan)'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final isOwner = user?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Settings & Profile'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryNavy,
          unselectedLabelColor: AppTheme.slateMuted,
          indicatorColor: AppTheme.mintTeal,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Profile & Clinic'),
            Tab(text: 'Hours & Holidays'),
            Tab(text: 'Staff Team'),
            Tab(text: 'Plan Templates'),
            Tab(text: 'Feature Toggles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClinicProfileTab(user, auth),
          _buildHoursAndHolidaysTab(),
          _buildStaffTeamTab(isOwner),
          _buildTemplatesTab(),
          _buildFeatureTogglesTab(),
        ],
      ),
    );
  }

  // --- TAB 1: CLINIC PROFILE & USER ---
  Widget _buildClinicProfileTab(UserModel? user, AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Doctor / User Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderGrey),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryNavy,
                  child: Text(
                    (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'D',
                    style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user?.name.isNotEmpty == true ? 'Dr. ${user!.name}' : 'Doctor / Staff',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.slateDark),
                            ),
                          ),
                          StatusBadge(status: user?.roleDisplayName ?? 'Staff'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted)),
                      if (user?.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(user!.phone!, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Clinic Details Section
          const Text(
            'Clinic Information',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderGrey),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              children: [
                _buildInfoTile(Icons.local_hospital_outlined, 'Clinic Name', _clinicName, onEdit: () => _editField('Clinic Name', _clinicName, (v) => setState(() => _clinicName = v))),
                const Divider(),
                _buildInfoTile(Icons.location_on_outlined, 'Address', _clinicAddress, onEdit: () => _editField('Address', _clinicAddress, (v) => setState(() => _clinicAddress = v))),
                const Divider(),
                _buildInfoTile(Icons.phone_outlined, 'Phone', _clinicPhone, onEdit: () => _editField('Phone', _clinicPhone, (v) => setState(() => _clinicPhone = v))),
                const Divider(),
                _buildInfoTile(Icons.schedule_outlined, 'Timezone', _timezone, onEdit: null),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Language Selection
          const Text(
            'Language Preference',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLanguageChip('English', 'en'),
                _buildLanguageChip('हिन्दी (Hindi)', 'hi'),
                _buildLanguageChip('मराठी (Marathi)', 'mr'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Demo Mode Tile
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderGrey),
            ),
            leading: const Icon(Icons.science_outlined, color: AppTheme.primaryTeal),
            title: const Text('Live Demo Simulation Mode', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Test short-interval reminder triggers for patient workflow demos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // Compliance & Legal Section
          const Text(
            'Compliance, Legal & Feedback',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderGrey),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryTeal),
                  title: const Text('Privacy Policy & DPDP Act Data Handling', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Digital Personal Data Protection Act compliance summary', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppTheme.primaryNavy),
                  title: const Text('Terms of Service & Clinical Care', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Clinical discretion, doctor responsibilities & emergency disclaimer', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined, color: Color(0xFF6366F1)),
                  title: const Text('Submit Pilot Feedback', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Report observations and workflow feedback for the pilot report', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Logout
          CustomButton(
            text: 'Sign Out of CareTrack',
            variant: ButtonVariant.danger,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out of CareTrack?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.statusMissedText),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await auth.signOut();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, String code) {
    final isSelected = _selectedLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.slateDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedLanguage = code);
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryTeal),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.slateMuted),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  // --- TAB 2: WORKING HOURS & HOLIDAYS ---
  Widget _buildHoursAndHolidaysTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Weekly Clinic Working Schedule',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderGrey),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              children: [
                _buildScheduleRow('Monday – Friday', '09:00 AM – 01:00 PM', '02:00 PM – 07:00 PM', true),
                const Divider(),
                _buildScheduleRow('Saturday', '09:00 AM – 02:00 PM', 'Afternoon Closed', true),
                const Divider(),
                _buildScheduleRow('Sunday', 'Closed', 'Emergency On-Call Only', false),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Default Slot Duration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('30 Minutes', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Clinic Holidays (2026)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Holiday'),
                onPressed: _showAddHolidayDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _holidays.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final h = _holidays[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.mintTeal.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.beach_access, size: 18, color: AppTheme.primaryTeal),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(h['date'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.slateMuted),
                      onPressed: () {
                        setState(() => _holidays.removeAt(index));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String day, String morning, String afternoon, bool isOpen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(day, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(morning, style: TextStyle(fontSize: 12, color: isOpen ? AppTheme.slateDark : AppTheme.slateMuted)),
                if (afternoon.isNotEmpty)
                  Text(afternoon, style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
              ],
            ),
          ),
          StatusBadge(status: isOpen ? 'Open' : 'Closed', fontSize: 10),
        ],
      ),
    );
  }

  // --- TAB 3: STAFF TEAM ---
  Widget _buildStaffTeamTab(bool isOwner) {
    return StreamBuilder<List<UserModel>>(
      stream: _adminService.streamDoctors(),
      builder: (context, snapshot) {
        final staffList = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Clinic Doctors & Staff',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                  if (isOwner)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Invite Staff'),
                      onPressed: _showInviteStaffDialog,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (staffList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderGrey),
                  ),
                  child: const Center(
                    child: Text('Loading clinic staff team...', style: TextStyle(color: AppTheme.slateMuted)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: staffList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = staffList[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderGrey),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryNavy.withAlpha(20),
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : 'S',
                              style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(member.email, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                              ],
                            ),
                          ),
                          StatusBadge(status: member.roleDisplayName),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 4: TREATMENT PLAN TEMPLATES ---
  Widget _buildTemplatesTab() {
    final templates = [
      {
        'title': 'Root Canal Treatment (3 Sittings)',
        'description': 'Standard multi-stage endodontic treatment protocol with pulp extirpation, canal shaping and obturation.',
        'stages': ['Pulp Extirpation & Dressing', 'Biomech Prep & Irrigation (7-day)', 'Obturation & Permanent Filling'],
      },
      {
        'title': 'Orthodontic Braces (Monthly Adjustments)',
        'description': 'Comprehensive bracket placement followed by 28-day recurring archwire adjustments.',
        'stages': ['Bonding & Initial Archwire', 'Monthly Tightening & Alignment', 'Finishing & Debonding'],
      },
      {
        'title': 'Scaling & Periodontal Maintenance (6 Months)',
        'description': 'Routine dental prophylaxis and periodontal probing every 6 months.',
        'stages': ['Ultrasonic Scaling & Polishing', '6-Month Periodontal Review'],
      },
      {
        'title': 'Dental Implant Stages',
        'description': 'Surgical fixture placement, osseointegration window, abutment and final crown delivery.',
        'stages': ['Implant Fixture Placement', 'Abutment Connection & Impression (90-day)', 'Final Crown Cementation'],
      },
      {
        'title': 'Tooth Extraction & Follow-up',
        'description': 'Surgical or simple extraction with mandatory 7-day healing and suture removal visit.',
        'stages': ['Extraction Procedure', '7-Day Post-Op Healing Check'],
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = templates[index];
        final stages = t['stages'] as List<String>;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                      t['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                    ),
                  ),
                  const StatusBadge(status: 'Pre-seeded Template', fontSize: 10),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t['description'] as String,
                style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 12),
              const Text('Stages:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: stages.asMap().entries.map((e) {
                  return Chip(
                    label: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 5: FEATURE TOGGLES ---
  Widget _buildFeatureTogglesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Clinic Feature Flags',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enable or disable modular retention components dynamically across the clinic platform.',
          style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
        ),
        const SizedBox(height: 16),
        _buildToggleTile(
          'Structured Treatment Plans',
          'Multi-stage dental scheduling engine with automated follow-up proposal',
          _flagTreatmentPlans,
          (v) => setState(() => _flagTreatmentPlans = v),
        ),
        _buildToggleTile(
          'Online Slot Booking',
          'Doctor slot management and patient self-booking with double-booking prevention',
          _flagOnlineBooking,
          (v) => setState(() => _flagOnlineBooking = v),
        ),
        _buildToggleTile(
          'Two-Way WhatsApp Inbox',
          'Clinic inbox with inbound replies, 24-hr reply window and post-care triage',
          _flagTwoWayWhatsApp,
          (v) => setState(() => _flagTwoWayWhatsApp = v),
        ),
        _buildToggleTile(
          'Automated Recall Campaigns',
          'Targeted 6-month overdue recall lists with bulk WhatsApp dispatch & anti-spam guard',
          _flagRecall,
          (v) => setState(() => _flagRecall = v),
        ),
        _buildToggleTile(
          'Medication Reminders',
          'Personalized WhatsApp dose reminders with adherence ring tracking',
          _flagMedicationReminders,
          (v) => setState(() => _flagMedicationReminders = v),
        ),
        _buildToggleTile(
          'AI No-Show Prediction',
          'Predictive risk score evaluating appointment lead time, channel and past misses',
          _flagNoShowAI,
          (v) => setState(() => _flagNoShowAI = v),
        ),
        _buildToggleTile(
          'Strict FAQ Assistant',
          'RAG assistant answering clinic logistics with source citations and clinical handoff',
          _flagFaqAssistant,
          (v) => setState(() => _flagFaqAssistant = v),
        ),
      ],
    );
  }

  Widget _buildToggleTile(String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppTheme.primaryTeal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _editField(String title, String currentVal, ValueChanged<String> onSaved) {
    final controller = TextEditingController(text: currentVal);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new $title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            onPressed: () {
              onSaved(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddHolidayDialog() {
    final nameCtrl = TextEditingController();
    DateTime picked = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Add Clinic Holiday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Holiday Name', hintText: 'e.g. Clinic Annual Day'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: AppTheme.primaryTeal),
                title: Text('Date: ${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.edit, size: 16),
                onTap: () async {
                  final d = await showDatePicker(
                    context: dialogCtx,
                    initialDate: picked,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setDialogState(() => picked = d);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _holidays.add({
                      'name': nameCtrl.text.trim(),
                      'date': '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'doctor';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Invite Staff Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Dr. Jane Doe'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', hintText: 'jane@clinic.com'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Staff Role'),
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'receptionist', child: Text('Receptionist / Front Desk')),
                  DropdownMenuItem(value: 'owner', child: Text('Clinic Owner / Admin')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => role = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Staff invitation dispatched to ${emailCtrl.text}'),
                    backgroundColor: AppTheme.statusConfirmedText,
                  ),
                );
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }
}
