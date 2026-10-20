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

  // Form Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'doctor';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
          role: _selectedRole,
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').replaceAll('FirebaseError:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.signInWithGoogle();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: isDesktop ? _buildDesktopLayout() : _buildMobileCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.hoverShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Hero Showcase Panel
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              decoration: const BoxDecoration(
                gradient: AppTheme.heroGradient,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CareTrack',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dental & Clinic Follow-up Management',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Automated patient follow-up scheduling, AI prescription extraction, and multi-channel SMS and Email reminders with full delivery tracking.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Feature badges
                    _buildFeatureItem(Icons.admin_panel_settings_outlined, 'Admin & Doctor Portal', 'Clinic management, doctor onboarding & patient 360'),
                    const SizedBox(height: 10),
                    _buildFeatureItem(Icons.auto_awesome, 'AI Prescription Recall', 'Auto-calculates standard +3m follow-up intervals'),
                    const SizedBox(height: 10),
                    _buildFeatureItem(Icons.mark_email_read_outlined, 'Twilio SMS & Email', 'Automated reminders sent directly to patient phones & inbox'),
                  ],
                ),
              ),
            ),
          ),

          // Right Authentication Form
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
              color: Colors.white,
              child: _buildFormContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                'CareTrack',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.slateDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Doctor Follow-up & Patient Care Portal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.slateMuted,
            ),
          ),
          const SizedBox(height: 24),
          _buildFormContent(),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Tab Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isSignUp ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: !_isSignUp
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                          color: !_isSignUp ? AppTheme.primaryNavy : AppTheme.slateMuted,
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isSignUp ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _isSignUp
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Register Account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                          color: _isSignUp ? AppTheme.primaryNavy : AppTheme.slateMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Error Box
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusDangerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.statusDangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.statusDanger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.statusDanger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Sign Up fields
          if (_isSignUp) ...[
            CustomTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'e.g. Dr. Rajesh Sharma',
              prefixIcon: const Icon(Icons.person_outline, size: 18, color: AppTheme.slateMuted),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 12),

            // Role selection
            Text(
              'Select Account Role',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'doctor'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'doctor' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: _selectedRole == 'doctor' ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 16,
                            color: _selectedRole == 'doctor' ? AppTheme.primaryBlue : AppTheme.slateMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Doctor',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedRole == 'doctor' ? AppTheme.primaryBlue : AppTheme.slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'admin'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'admin' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: _selectedRole == 'admin' ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 16,
                            color: _selectedRole == 'admin' ? AppTheme.primaryBlue : AppTheme.slateMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Admin',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedRole == 'admin' ? AppTheme.primaryBlue : AppTheme.slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'view_only'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'view_only' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: _selectedRole == 'view_only' ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: _selectedRole == 'view_only' ? AppTheme.primaryBlue : AppTheme.slateMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'View-Only',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedRole == 'view_only' ? AppTheme.primaryBlue : AppTheme.slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            CustomTextField(
              controller: _phoneController,
              label: 'Phone (Optional)',
              hint: '+91 9876543210',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppTheme.slateMuted),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Demo 1-Tap Fillers on Sign-In
          if (!_isSignUp) ...[
            Text(
              'Quick Demo Logins (1-Tap Test):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildDemoChip(
                  label: '👨‍⚕️ Doctor',
                  email: 'doctor@caretrack.com',
                  pass: 'Doctor@123',
                ),
                _buildDemoChip(
                  label: '🛡️ Admin',
                  email: 'admin@caretrack.com',
                  pass: 'Admin@123',
                ),
                _buildDemoChip(
                  label: '👁️ View-Only',
                  email: 'viewer@caretrack.com',
                  pass: 'Viewer@123',
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Email Field
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: _isSignUp ? 'doctor@clinic.com' : 'e.g. doctor@clinic.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppTheme.slateMuted),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter your email';
              if (!val.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password Field
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hint: _isSignUp ? 'Min 6 characters' : 'Enter password',
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.slateMuted),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter your password';
              if (_isSignUp && val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Submit Button
          CustomButton(
            text: _isSignUp ? 'Create Account' : 'Sign In to Portal',
            onPressed: _handleAuth,
            isLoading: _isLoading,
            icon: _isSignUp ? Icons.person_add_alt_1 : Icons.login,
          ),
          const SizedBox(height: 16),

          // Divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slateMuted,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),

          // Google Sign-In Button
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
            icon: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFEA4335),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            label: Text(
              'Continue with Google / Gmail',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChip({
    required String label,
    required String email,
    required String pass,
  }) {
    return ActionChip(
      avatar: const Icon(Icons.touch_app, size: 13, color: AppTheme.primaryBlue),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryNavy,
        ),
      ),
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: () {
        setState(() {
          _emailController.text = email;
          _passwordController.text = pass;
          _errorMessage = null;
        });
      },
    );
  }
}
