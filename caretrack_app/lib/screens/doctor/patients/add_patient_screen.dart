import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import '../../../services/comms_sender_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../appointments/add_appointment_screen.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientService = PatientService();
  final _commsService = CommsSenderService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitPatient() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    // Enforce requirement: Name AND (Mobile OR Email)
    if (phone.isEmpty && email.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide either a mobile number or an email address for reminders.';
      });
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final doctorId = auth.currentUser?.uid ?? 'doc_01';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final patientName = _nameController.text.trim();
      final patientId = await _patientService.addPatient(
        doctorId: doctorId,
        name: patientName,
        age: _ageController.text.isNotEmpty ? int.tryParse(_ageController.text) : null,
        dateOfBirth: _dobController.text.isNotEmpty ? _dobController.text : null,
        phone: phone.isNotEmpty ? phone : null,
        email: email.isNotEmpty ? email : null,
        address: _addressController.text.isNotEmpty ? _addressController.text.trim() : null,
      );

      final patient = await _patientService.getPatient(patientId);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show post-registration instant communication sheet
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Color(0xFF16A34A), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Registered!',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.slateDark,
                            ),
                          ),
                          Text(
                            '$patientName is added to CareTrack.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Instant Multi-Channel Communication:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                ),
                const SizedBox(height: 12),

                if (phone.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _commsService.sendSms(
                              doctorId: doctorId,
                              patientId: patientId,
                              phone: phone,
                              message: 'Hello $patientName, welcome to CareTrack Dental Clinic! Your profile has been registered.',
                              context: context,
                            );
                          },
                          icon: const Icon(Icons.sms_outlined, size: 16, color: AppTheme.primaryBlue),
                          label: Text('Send SMS ($phone)', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _commsService.sendWhatsApp(
                              doctorId: doctorId,
                              patientId: patientId,
                              phone: phone,
                              message: 'Hello $patientName, welcome to CareTrack Dental Clinic! Your profile has been registered.',
                              context: context,
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF10B981)),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                if (email.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      _commsService.sendEmail(
                        doctorId: doctorId,
                        patientId: patientId,
                        email: email,
                        subject: 'Welcome to CareTrack Dental Clinic',
                        body: 'Dear $patientName,\n\nWelcome to CareTrack Dental Clinic! Your patient profile has been registered for clinical care and follow-up reminders.\n\nBest regards,\nCareTrack Team',
                        context: context,
                      );
                    },
                    icon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF6366F1)),
                    label: Text('Send Welcome Email ($email)', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    if (patient != null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddAppointmentScreen(preselectedPatient: patient),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: const Text('Book Appointment'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, patientId);
                        },
                        child: const Text('Return to Dashboard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );

        if (mounted) {
          Navigator.pop(context, patientId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Patient'),
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
                label: 'Patient Full Name *',
                hint: 'e.g. Rajesh Kumar',
                prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppTheme.slateMuted),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),

              // Age & Date of Birth row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      controller: _ageController,
                      label: 'Age',
                      hint: 'e.g. 34',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      controller: _dobController,
                      label: 'Date of Birth',
                      hint: 'YYYY-MM-DD',
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mobile Number
              CustomTextField(
                controller: _phoneController,
                label: 'Mobile Number (for SMS reminders)',
                hint: 'e.g. +91 9876543210',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 16),

              // Email
              CustomTextField(
                controller: _emailController,
                label: 'Email Address (for email reminders)',
                hint: 'e.g. rajesh@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 16),

              // Address
              CustomTextField(
                controller: _addressController,
                label: 'Address / Location',
                hint: 'e.g. Sector 4, Gandhinagar',
                maxLines: 2,
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: 'Register Patient & Send Welcome',
                onPressed: _submitPatient,
                isLoading: _isLoading,
                icon: Icons.person_add_alt_1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
