import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/notification_model.dart';
import 'offline_store.dart';
import 'local_storage_adapter.dart';
import '../core/supabase_config.dart';

class CommsSenderService {
  static final CommsSenderService _instance = CommsSenderService._internal();
  factory CommsSenderService() => _instance;
  CommsSenderService._internal();

  final _supabase = SupabaseConfig.client;

  // Email & Clinic metadata
  static const String clinicEmailName = 'CareTrack Clinic';
  static const String clinicEmail = 'caretrack.clinic@gmail.com';

  /// Clean phone number for international/local format
  String sanitizePhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+')) {
      if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      } else {
        cleaned = '+$cleaned';
      }
    }
    return cleaned;
  }

  /// Launch SMS (Device Messages App popup with pre-filled message)
  Future<bool> sendSms({
    required String doctorId,
    required String patientId,
    required String phone,
    required String message,
    BuildContext? context,
  }) async {
    final cleanNumber = sanitizePhone(phone);

    _logNotification(
      doctorId: doctorId,
      patientId: patientId,
      channel: 'sms',
      type: 'patient_sms',
      recipient: cleanNumber,
      status: 'Sent',
    );

    // Direct native SMS URI to open mobile/device Messages App popup
    final smsUri = Uri(
      scheme: 'sms',
      path: cleanNumber,
      queryParameters: {'body': message},
    );

    bool openedApp = false;
    try {
      openedApp = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (context != null && context.mounted) {
      if (openedApp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Device SMS app opened for $cleanNumber!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        await Clipboard.setData(ClipboardData(text: message));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copied to clipboard for direct sending.'),
              backgroundColor: Color(0xFF0284C7),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }

    return openedApp;
  }

  /// Launch WhatsApp direct message
  Future<bool> sendWhatsApp({
    required String doctorId,
    required String patientId,
    required String phone,
    required String message,
    BuildContext? context,
  }) async {
    var cleanNumber = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final waUrl = 'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}';

    _logNotification(
      doctorId: doctorId,
      patientId: patientId,
      channel: 'whatsapp',
      type: 'whatsapp_message',
      recipient: phone,
    );

    try {
      final ok = await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
      if (!ok && context != null && context.mounted) {
        await Clipboard.setData(ClipboardData(text: message));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp message copied to clipboard!')),
          );
        }
      }
      return ok;
    } catch (e) {
      if (context != null && context.mounted) {
        await Clipboard.setData(ClipboardData(text: message));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp message copied to clipboard!')),
          );
        }
      }
      return false;
    }
  }

  /// Launch Email composer with CareTrack Clinic configuration
  Future<bool> sendEmail({
    required String doctorId,
    required String patientId,
    required String email,
    required String subject,
    required String body,
    BuildContext? context,
  }) async {
    final cleanEmail = email.trim();
    final formattedSubject = subject.startsWith('[$clinicEmailName]') ? subject : '[$clinicEmailName] $subject';
    final fullEmailBody = '$body\n\n--\n$clinicEmailName\nContact: $clinicEmail';

    _logNotification(
      doctorId: doctorId,
      patientId: patientId,
      channel: 'email',
      type: 'patient_email',
      recipient: cleanEmail,
    );

    final gmailWebUrl = 'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(cleanEmail)}&su=${Uri.encodeComponent(formattedSubject)}&body=${Uri.encodeComponent(fullEmailBody)}';
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: cleanEmail,
      queryParameters: {
        'subject': formattedSubject,
        'body': fullEmailBody,
      },
    );

    bool launched = false;
    try {
      // 1. Try native mailto
      launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        // 2. Fallback to Gmail Web in browser
        launched = await launchUrl(Uri.parse(gmailWebUrl), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched && context != null && context.mounted) {
      await Clipboard.setData(ClipboardData(text: 'To: $cleanEmail\nFrom: $clinicEmail\nSubject: $formattedSubject\n\n$fullEmailBody'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email formatted for $cleanEmail copied to clipboard!'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }
    }

    return launched;
  }

  /// Interactive Message Composer Dialog for Demo & Live Testing
  Future<void> openMessageComposerDialog({
    required BuildContext context,
    required String doctorId,
    required String patientId,
    required String patientName,
    String? initialPhone,
    String? initialEmail,
    String initialChannel = 'sms',
    String? defaultMessage,
    String? defaultSubject,
  }) async {
    String selectedChannel = initialChannel;
    final recipientCtrl = TextEditingController(
      text: selectedChannel == 'email' ? (initialEmail ?? '') : (initialPhone ?? ''),
    );
    final subjectCtrl = TextEditingController(
      text: defaultSubject ?? 'CareTrack Dental Clinic Care Update',
    );
    final messageCtrl = TextEditingController(
      text: defaultMessage ??
          'Hello $patientName,\nThis is a clinical update from CareTrack Dental Clinic regarding your routine checkup and care schedule. Please contact us for any assistance.\n\nBest regards,\nCareTrack Clinic',
    );

    final savedDemoPhone = LocalStorageAdapter.getItem('caretrack_demo_phone') ?? '';
    final savedDemoEmail = LocalStorageAdapter.getItem('caretrack_demo_email') ?? '';

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.send_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Actual Message',
                          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Patient: $patientName',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Channel Selector Tabs
                    Row(
                      children: [
                        _buildChannelChip(
                          label: 'Direct SMS',
                          icon: Icons.sms_outlined,
                          isSelected: selectedChannel == 'sms',
                          color: const Color(0xFF2563EB),
                          onTap: () {
                            setModalState(() {
                              selectedChannel = 'sms';
                              recipientCtrl.text = initialPhone ?? savedDemoPhone;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildChannelChip(
                          label: 'WhatsApp',
                          icon: Icons.chat_bubble_outline,
                          isSelected: selectedChannel == 'whatsapp',
                          color: const Color(0xFF10B981),
                          onTap: () {
                            setModalState(() {
                              selectedChannel = 'whatsapp';
                              recipientCtrl.text = initialPhone ?? savedDemoPhone;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildChannelChip(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          isSelected: selectedChannel == 'email',
                          color: const Color(0xFF6366F1),
                          onTap: () {
                            setModalState(() {
                              selectedChannel = 'email';
                              recipientCtrl.text = initialEmail ?? savedDemoEmail;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Test Helper Chips
                    Wrap(
                      spacing: 8,
                      children: [
                        if (savedDemoPhone.isNotEmpty && selectedChannel != 'email')
                          ActionChip(
                            avatar: const Icon(Icons.phone_android, size: 14),
                            label: Text('Use Saved Number: $savedDemoPhone', style: const TextStyle(fontSize: 11)),
                            onPressed: () => setModalState(() => recipientCtrl.text = savedDemoPhone),
                          ),
                        if (savedDemoEmail.isNotEmpty && selectedChannel == 'email')
                          ActionChip(
                            avatar: const Icon(Icons.alternate_email, size: 14),
                            label: Text('Use Saved Email: $savedDemoEmail', style: const TextStyle(fontSize: 11)),
                            onPressed: () => setModalState(() => recipientCtrl.text = savedDemoEmail),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Recipient Field
                    Text(
                      selectedChannel == 'email'
                          ? 'Recipient Email (You can enter your temporary email):'
                          : 'Recipient Phone Number (Enter your mobile number to test):',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: recipientCtrl,
                      keyboardType: selectedChannel == 'email' ? TextInputType.emailAddress : TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: selectedChannel == 'email' ? 'e.g. your_temp_email@guerrillamail.com' : 'e.g. +91 9876543210',
                        prefixIcon: Icon(selectedChannel == 'email' ? Icons.email : Icons.phone, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Subject Field (for Email)
                    if (selectedChannel == 'email') ...[
                      Text(
                        'Email Subject:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: subjectCtrl,
                        decoration: InputDecoration(
                          hintText: 'Email Subject',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Message Body Field
                    Text(
                      'Message Content (Actual text to be sent):',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter clinical message or reminder...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text('Send Live ${selectedChannel.toUpperCase()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedChannel == 'sms'
                        ? const Color(0xFF2563EB)
                        : (selectedChannel == 'whatsapp' ? const Color(0xFF10B981) : const Color(0xFF6366F1)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () async {
                    final target = recipientCtrl.text.trim();
                    final msg = messageCtrl.text.trim();
                    if (target.isEmpty) return;

                    // Remember demo credentials for quick future tests
                    if (selectedChannel == 'email') {
                      LocalStorageAdapter.setItem('caretrack_demo_email', target);
                    } else {
                      LocalStorageAdapter.setItem('caretrack_demo_phone', target);
                    }

                    Navigator.pop(dialogCtx);

                    if (selectedChannel == 'sms') {
                      await sendSms(
                        doctorId: doctorId,
                        patientId: patientId,
                        phone: target,
                        message: msg,
                        context: context,
                      );
                    } else if (selectedChannel == 'whatsapp') {
                      await sendWhatsApp(
                        doctorId: doctorId,
                        patientId: patientId,
                        phone: target,
                        message: msg,
                        context: context,
                      );
                    } else if (selectedChannel == 'email') {
                      await sendEmail(
                        doctorId: doctorId,
                        patientId: patientId,
                        email: target,
                        subject: subjectCtrl.text.trim(),
                        body: msg,
                        context: context,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildChannelChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Internal logger for real-time tracking
  void _logNotification({
    required String doctorId,
    required String patientId,
    required String channel,
    required String type,
    required String recipient,
    String status = 'Sent',
  }) {
    final now = DateTime.now();
    final notif = NotificationModel(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      patientId: patientId,
      channel: channel,
      type: type,
      recipient: recipient,
      status: status,
      sentAt: now,
      createdAt: now,
    );

    OfflineStore().addNotification(notif);
    _supabase.from('notifications').insert(notif.toMap()).catchError((_) {});
  }
}
