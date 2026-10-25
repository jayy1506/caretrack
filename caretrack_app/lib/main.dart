import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/demo_service.dart';
import 'services/connectivity_service.dart';
import 'services/clinic_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/doctor/doctor_shell_screen.dart';
import 'screens/receptionist/receptionist_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase using --dart-define parameters with fallback
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ClinicService()),
        ChangeNotifierProvider(create: (_) => DemoService()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: const CareTrackApp(),
    ),
  );
}

class CareTrackApp extends StatelessWidget {
  const CareTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing CareTrack...',
                style: TextStyle(color: AppTheme.slateMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated || auth.currentUser == null) {
      return const LoginScreen();
    }

    // Role-based routing: Owner -> Admin shell, Receptionist -> Receptionist shell, Doctor -> Doctor shell
    if (auth.currentUser!.isAdmin || auth.currentUser!.isOwner) {
      return const AdminDashboardScreen();
    }
    if (auth.currentUser!.isReceptionist) {
      return ReceptionistShellScreen(clinicId: auth.currentUser!.clinicId);
    }

    return const DoctorShellScreen();
  }
}
