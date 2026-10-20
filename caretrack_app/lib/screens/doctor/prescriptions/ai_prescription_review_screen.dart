import 'package:flutter/material.dart';
import '../../../models/patient_model.dart';
import '../../../models/prescription_safety_warning.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/prescription_safety_banner.dart';

class AiPrescriptionReviewScreen extends StatefulWidget {
  final PatientModel patient;
  final String? imageUrl;
  final List<Map<String, String>> initialMedicines;
  final String? followUpType;
  final String? followUpDate;
  final String? confidenceNote;
  final List<PrescriptionSafetyWarning> safetyWarnings;

  const AiPrescriptionReviewScreen({
    super.key,
    required this.patient,
    this.imageUrl,
    required this.initialMedicines,
    this.followUpType,
    this.followUpDate,
    this.confidenceNote,
    this.safetyWarnings = const [],
  });

  @override
  State<AiPrescriptionReviewScreen> createState() => _AiPrescriptionReviewScreenState();
}

class _AiPrescriptionReviewScreenState extends State<AiPrescriptionReviewScreen> {
  late List<Map<String, TextEditingController>> _medicineControllers;
  late TextEditingController _followUpDateController;
  late List<PrescriptionSafetyWarning> _warnings;
  bool _isOverridden = false;
  String? _overrideReason;

  @override
  void initState() {
    super.initState();
    _warnings = List.from(widget.safetyWarnings);
    _followUpDateController = TextEditingController(text: widget.followUpDate ?? '');

    _medicineControllers = widget.initialMedicines.map((m) {
      return {
        'name': TextEditingController(text: m['name'] ?? ''),
        'dosage': TextEditingController(text: m['dosage'] ?? ''),
        'frequency': TextEditingController(text: m['frequency'] ?? ''),
        'duration': TextEditingController(text: m['duration'] ?? ''),
        'instructions': TextEditingController(text: m['instructions'] ?? ''),
      };
    }).toList();
  }

  @override
  void dispose() {
    _followUpDateController.dispose();
    for (final row in _medicineControllers) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addMedicineRow() {
    setState(() {
      _medicineControllers.add({
        'name': TextEditingController(),
        'dosage': TextEditingController(),
        'frequency': TextEditingController(),
        'duration': TextEditingController(),
        'instructions': TextEditingController(),
      });
    });
  }

  void _removeMedicineRow(int index) {
    setState(() {
      final removed = _medicineControllers.removeAt(index);
      for (final c in removed.values) {
        c.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Prescription: ${widget.patient.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Verification Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI-Assisted Optical Extraction',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Please review and verify extracted items below. Clinical advice is never sent automatically.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Prescription Safety Banner
            PrescriptionSafetyBanner(
              warnings: _warnings,
              isOverridden: _isOverridden,
              onDoctorOverride: (reason) {
                setState(() {
                  _isOverridden = true;
                  _overrideReason = reason;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Doctor override confirmed and recorded in audit log.'),
                    backgroundColor: AppTheme.primaryNavy,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Responsive Layout: side-by-side on desktop, stacked on mobile
            if (isDesktop && widget.imageUrl != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildImagePreview(),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _buildFormContent(),
                  ),
                ],
              )
            else ...[
              if (widget.imageUrl != null) ...[
                _buildImagePreview(),
                const SizedBox(height: 20),
              ],
              _buildFormContent(),
            ],

            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Confirm & Activate Prescription',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final medicines = _medicineControllers.map((row) {
                  return {
                    'name': row['name']!.text.trim(),
                    'dosage': row['dosage']!.text.trim(),
                    'frequency': row['frequency']!.text.trim(),
                    'duration': row['duration']!.text.trim(),
                    'instructions': row['instructions']!.text.trim(),
                  };
                }).toList();

                Navigator.pop(context, {
                  'medicines': medicines,
                  'followUpDate': _followUpDateController.text.trim(),
                  'isOverridden': _isOverridden,
                  'overrideReason': _overrideReason,
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          widget.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, size: 40, color: AppTheme.slateMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prescribed Medications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
              TextButton.icon(
                onPressed: _addMedicineRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Drug'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          ..._medicineControllers.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: row['name'],
                            decoration: const InputDecoration(labelText: 'Medicine Name', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row['dosage'],
                            decoration: const InputDecoration(labelText: 'Dosage (e.g. 500mg)', isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.statusMissedText, size: 20),
                          onPressed: () => _removeMedicineRow(idx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row['frequency'],
                            decoration: const InputDecoration(labelText: 'Frequency (e.g. BD)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row['duration'],
                            decoration: const InputDecoration(labelText: 'Duration (e.g. 5 days)', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 14),
          TextField(
            controller: _followUpDateController,
            decoration: const InputDecoration(
              labelText: 'Calculated Follow-Up Date (YYYY-MM-DD)',
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
