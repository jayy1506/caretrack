import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/bottom_nav_pill.dart';
import '../../core/theme/app_theme.dart';
import 'doctor_dashboard_screen.dart';
import 'patients/patient_list_screen.dart';
import 'appointments/appointment_list_screen.dart';
import 'communication/communication_history_screen.dart';
import 'settings/profile_screen.dart';

class DoctorShellScreen extends StatefulWidget {
  const DoctorShellScreen({super.key});

  @override
  State<DoctorShellScreen> createState() => _DoctorShellScreenState();
}

class _DoctorShellScreenState extends State<DoctorShellScreen> {
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
      DoctorDashboardScreen(onNavigateTab: _onTabTapped),
      const PatientListScreen(),
      const AppointmentListScreen(),
      const CommunicationHistoryScreen(),
      const ProfileScreen(),
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
                  // Desktop Modern Sidebar
                  Container(
                    width: 240,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Clinic Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNavy,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
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
                                    'Dental & Clinic Portal',
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
                        const Divider(),

                        // Navigation Items
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            children: [
                              _buildSidebarNavItem(0, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard),
                              _buildSidebarNavItem(1, 'Patients & Rx', Icons.people_outline, Icons.people),
                              _buildSidebarNavItem(2, 'Appointments', Icons.calendar_month_outlined, Icons.calendar_month),
                              _buildSidebarNavItem(3, 'Comms History', Icons.outgoing_mail, Icons.mark_email_read),
                              _buildSidebarNavItem(4, 'Doctor Profile', Icons.person_outline, Icons.person),
                            ],
                          ),
                        ),

                        if (auth.currentUser?.isViewOnly == true)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.visibility, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'View-Only Access (Read Only)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Doctor Profile Chip at bottom
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
                                backgroundColor: auth.currentUser?.isViewOnly == true
                                    ? const Color(0xFFD97706)
                                    : AppTheme.primaryNavy,
                                child: Text(
                                  auth.currentUser?.name.isNotEmpty == true
                                      ? auth.currentUser!.name[0].toUpperCase()
                                      : 'U',
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
                                      auth.currentUser?.name ?? 'User',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.slateDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      auth.currentUser?.roleDisplayName ?? 'Doctor',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: auth.currentUser?.isViewOnly == true
                                            ? const Color(0xFFD97706)
                                            : AppTheme.slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, size: 18, color: AppTheme.slateMuted),
                                onPressed: () => auth.signOut(),
                                tooltip: 'Sign Out',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: screens[_currentIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile View
    return Scaffold(
      body: Column(
        children: [
          OfflineBanner(isOffline: connectivity.isOffline),
          Expanded(
            child: screens[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavPill(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
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
          BottomNavPillItem(
            icon: Icons.outgoing_mail,
            activeIcon: Icons.mark_email_read,
            label: 'Comms',
          ),
          BottomNavPillItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
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
                color: isSelected ? AppTheme.primaryNavy : AppTheme.slateMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryNavy : AppTheme.slateDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
