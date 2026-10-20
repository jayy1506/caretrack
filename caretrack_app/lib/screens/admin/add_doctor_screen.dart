import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';

class AddDoctorScreen extends StatefulWidget {
  const AddDoctorScreen({super.key});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isActive = true;
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

  Future<void> _submitDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _adminService.createDoctor(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        active: _isActive,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final doctorName = _nameController.text.trim();
        Navigator.pop(context, true);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Doctor "$doctorName" created successfully!')),
              ],
            ),
            backgroundColor: AppTheme.statusSuccess,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').replaceAll('FirebaseFunctionsException:', '').trim();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Doctor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusDangerBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusDanger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.statusDanger, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Full Name
              CustomTextField(
                controller: _nameController,
                label: 'Doctor Full Name *',
                hint: 'e.g. Dr. Rajesh Sharma',
                prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppTheme.slateMuted),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),

              // Email
              CustomTextField(
                controller: _emailController,
                label: 'Email Address *',
                hint: 'e.g. dr.sharma@clinic.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppTheme.slateMuted),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!val.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone
              CustomTextField(
                controller: _phoneController,
                label: 'Mobile Number',
                hint: 'e.g. +91 9876543210',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 16),

              // Temporary Password
              CustomTextField(
                controller: _passwordController,
                label: 'Temporary Password *',
                hint: 'Minimum 6 characters',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.slateMuted),
                validator: (val) {
                  if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Active / Disabled status switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Status',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          'Allow doctor to sign in immediately',
                          style: TextStyle(color: AppTheme.slateMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      activeThumbColor: AppTheme.primaryNavy,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: 'Create Doctor Account',
                onPressed: _submitDoctor,
                isLoading: _isLoading,
                icon: Icons.person_add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
