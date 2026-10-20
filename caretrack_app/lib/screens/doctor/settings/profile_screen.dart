import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import 'demo_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Doctor ID Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                          Text(
                            'Dr. ${user?.name ?? "Doctor"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.slateDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                          ),
                          if (user?.phone != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              user!.phone!,
                              style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Settings Section
            const Text(
              'App Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slateDark),
            ),
            const SizedBox(height: 10),

            // Messaging Gateway Status Tile
            ListTile(
              tileColor: AppTheme.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppTheme.borderGrey),
              ),
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
              title: const Text('Clinic Messaging Engine', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Cloud Functions Gateway: WhatsApp & Gmail SMTP',
                style: TextStyle(fontSize: 12, color: AppTheme.statusSuccess),
              ),
            ),
            const SizedBox(height: 10),

            ListTile(
              tileColor: AppTheme.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppTheme.borderGrey),
              ),
              leading: const Icon(Icons.science_outlined, color: AppTheme.primaryNavy),
              title: const Text('Demo / Test Reminder Mode', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Test short-interval reminder triggers for live demo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DemoSettingsScreen()),
              ),
            ),
            const SizedBox(height: 30),

            // Logout Button
            CustomButton(
              text: 'Log Out',
              variant: ButtonVariant.danger,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out of CareTrack?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.statusDanger),
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
      ),
    );
  }
}
