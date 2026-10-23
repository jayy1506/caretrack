import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (_isSignUp) {
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: 'doctor',
        );
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _fillDemoCredentials(String email, String password) {
    setState(() {
      _isSignUp = false;
      _emailController.text = email;
      _passwordController.text = password;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderGrey),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : AppTheme.softShadow,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.mintAccent.withAlpha(35) : AppTheme.primaryNavy,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.local_hospital_rounded,
                            color: isDark ? AppTheme.mintAccent : Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'CareTrack',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.primaryNavy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? 'Create your clinic doctor account'
                            : 'Sign in to access your dental portal',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppTheme.slateMuted,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In / Sign Up Tab Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : AppTheme.backgroundGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  _isSignUp = false;
                                  _errorMessage = null;
                                }),
                                borderRadius: BorderRadius.circular(9),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: !_isSignUp
                                        ? (isDark ? AppTheme.darkSurface : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: !_isSignUp
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(isDark ? 50 : 12),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign In',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                                      color: !_isSignUp
                                          ? (isDark ? Colors.white : AppTheme.primaryNavy)
                                          : (isDark ? Colors.white60 : AppTheme.slateMuted),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  _isSignUp = true;
                                  _errorMessage = null;
                                }),
                                borderRadius: BorderRadius.circular(9),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: _isSignUp
                                        ? (isDark ? AppTheme.darkSurface : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: _isSignUp
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(isDark ? 50 : 12),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign Up',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                                      color: _isSignUp
                                          ? (isDark ? Colors.white : AppTheme.primaryNavy)
                                          : (isDark ? Colors.white60 : AppTheme.slateMuted),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error message if any
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.statusMissedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.statusMissedText.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.statusMissedText, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.statusMissedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full name only for Sign Up
                      if (_isSignUp) ...[
                        CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Dr. Jane Smith',
                          prefixIcon: const Icon(Icons.person_outline, size: 18, color: AppTheme.slateMuted),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email input
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'doctor@caretrack.local',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppTheme.slateMuted),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter your email';
                          if (!val.contains('@')) return 'Enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password input
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.slateMuted),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please enter your password';
                          if (_isSignUp && val.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      // Action Button
                      CustomButton(
                        text: _isSignUp ? 'Create Account' : 'Sign In',
                        onPressed: _handleAuth,
                        isLoading: _isLoading,
                        icon: _isSignUp ? Icons.person_add_alt_1 : Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 20),

                      // Quick 1-Tap Demo Shortcuts
                      if (!_isSignUp) ...[
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'QUICK DEMO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.slateMuted,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _fillDemoCredentials('doctor.a@caretrack.local', 'Password@123'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderGrey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  'Doctor',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.mintAccent : AppTheme.primaryTeal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _fillDemoCredentials('receptionist.demo@caretrack.local', 'Password@123'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderGrey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  'Receptionist',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppTheme.primaryNavy,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _fillDemoCredentials('owner.demo@caretrack.local', 'Password@123'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderGrey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  'Owner',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
