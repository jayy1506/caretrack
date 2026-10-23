import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/bottom_nav_pill.dart';
import '../../core/theme/app_theme.dart';
import 'receptionist_home_screen.dart';
import '../doctor/appointments/appointment_list_screen.dart';
import '../doctor/inbox/inbox_screen.dart';
import '../doctor/patients/patient_list_screen.dart';

class ReceptionistShellScreen extends StatefulWidget {
  final String clinicId;

  const ReceptionistShellScreen({super.key, this.clinicId = 'default-clinic'});

  @override
  State<ReceptionistShellScreen> createState() => _ReceptionistShellScreenState();
}

class _ReceptionistShellScreenState extends State<ReceptionistShellScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = Provider.of<ConnectivityService>(context);
    final auth = Provider.of<AuthService>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    final List<Widget> screens = [
      ReceptionistHomeScreen(clinicId: widget.clinicId),
      const AppointmentListScreen(),
      InboxScreen(clinicId: widget.clinicId),
      const PatientListScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            OfflineBanner(isOffline: connectivity.isOffline),
            Expanded(
              child: Row(
                children: [
                  // Desktop Sidebar (>900px)
                  Container(
                    width: 240,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Clinic & Portal Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.desk_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CareTrack',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.slateDark,
                                    ),
                                  ),
                                  Text(
                                    'Front Desk & Reception',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppTheme.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Navigation Items
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            children: [
                              _buildSidebarNavItem(0, 'Front Desk', Icons.calendar_today_outlined, Icons.calendar_today),
                              _buildSidebarNavItem(1, 'Appointments', Icons.calendar_month_outlined, Icons.calendar_month),
                              _buildSidebarNavItem(2, 'WhatsApp Inbox', Icons.mark_chat_unread_outlined, Icons.mark_chat_unread),
                              _buildSidebarNavItem(3, 'Patient Directory', Icons.people_outline, Icons.people),
                            ],
                          ),
                        ),

                        // User profile footer & sign out
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryTeal,
                                child: Text(
                                  auth.currentUser?.name.isNotEmpty == true
                                      ? auth.currentUser!.name[0].toUpperCase()
                                      : 'R',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      auth.currentUser?.name ?? 'Receptionist',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.slateDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'Reception Staff',
                                      style: TextStyle(fontSize: 10, color: AppTheme.slateMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, size: 18, color: AppTheme.slateMuted),
                                tooltip: 'Sign Out',
                                onPressed: () => auth.signOut(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Area
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout (<= 900px)
    return Scaffold(
      body: Column(
        children: [
          OfflineBanner(isOffline: connectivity.isOffline),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavPill(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavPillItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today,
            label: 'Front Desk',
          ),
          BottomNavPillItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'Visits',
          ),
          BottomNavPillItem(
            icon: Icons.mark_chat_unread_outlined,
            activeIcon: Icons.mark_chat_unread,
            label: 'Inbox',
          ),
          BottomNavPillItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Patients',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected ? AppTheme.primaryTeal : AppTheme.slateMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryTeal : AppTheme.slateDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
