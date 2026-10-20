import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/patient_model.dart';
import '../../../models/prescription_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import '../../../services/prescription_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final PatientModel? patient;

  const AddPrescriptionScreen({super.key, this.patient});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _prescriptionService = PrescriptionService();
  final _patientService = PatientService();

  PatientModel? _selectedPatient;
  DateTime _prescriptionDate = DateTime.now();
  String _followUpType = '3_months'; // '15_days' | '1_month' | '3_months' | '6_months' | 'custom'
  DateTime _calculatedFollowUpDate = DateTime.now().add(const Duration(days: 90));
  DateTime? _customFollowUpDate;

  // Medicine items list
  final List<MedicineItemModel> _medicines = [];

  // File upload state
  PlatformFile? _pickedFile;
  bool _isExtracting = false;
  bool _isSaving = false;
  bool _aiExtracted = false;
  String? _aiExtractionNote;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.patient;
    _recalculateFollowUp();
    _addMedicineRow();
  }

  void _addMedicineRow({String name = '', String dosage = '', String freq = '', String dur = '', String inst = ''}) {
    setState(() {
      _medicines.add(MedicineItemModel(
        name: name,
        dosage: dosage,
        frequency: freq,
        duration: dur,
        instructions: inst,
      ));
    });
  }

  void _removeMedicineRow(int index) {
    setState(() {
      if (_medicines.length > 1) {
        _medicines.removeAt(index);
      }
    });
  }

  void _recalculateFollowUp() {
    setState(() {
      _calculatedFollowUpDate = DateUtilsHelper.calculateFollowUp(
        _prescriptionDate,
        _followUpType,
        customDate: _customFollowUpDate,
      );
    });
  }

  Future<void> _pickPrescriptionFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select file: $e';
      });
    }
  }

  Future<void> _runAiExtraction() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() {
        _errorMessage = 'Please select a document file first.';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final ext = _pickedFile!.extension?.toLowerCase();
      final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/${ext == 'png' ? 'png' : 'jpeg'}';

      final extractedData = await _prescriptionService.extractFromPrescription(
        fileBytes: _pickedFile!.bytes!,
        mimeType: mimeType,
      );

      setState(() {
        _aiExtracted = true;
        _aiExtractionNote = 'Extracted by Gemini AI. Please verify details.';

        // Populate medicines
        if (extractedData['medicines'] != null && extractedData['medicines'] is List) {
          _medicines.clear();
          for (final med in (extractedData['medicines'] as List)) {
            _medicines.add(MedicineItemModel(
              name: med['name']?.toString() ?? '',
              dosage: med['dosage']?.toString() ?? '',
              frequency: med['frequency']?.toString() ?? '',
              duration: med['duration']?.toString() ?? '',
              instructions: med['instructions']?.toString() ?? '',
            ));
          }
        }

        // Populate follow-up if suggested
        if (extractedData['suggestedFollowUp'] != null) {
          _followUpType = extractedData['suggestedFollowUp'].toString();
          _recalculateFollowUp();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'AI extraction encountered an issue: $e. You can still enter medicines manually.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _handleSaveAndSchedule() async {
    final currentPatient = _selectedPatient ?? widget.patient;
    if (currentPatient == null) {
      setState(() => _errorMessage = 'Please select a patient first.');
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final doctorId = (auth.currentUser?.uid != null && auth.currentUser!.uid.isNotEmpty)
        ? auth.currentUser!.uid
        : 'doc_01';

    final validMedicines = _medicines.where((m) => m.name.trim().isNotEmpty).toList();
    if (validMedicines.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one medication name.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      String? originalFileUrl;

      // Upload file to Firebase Storage if attached
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        final ext = _pickedFile!.extension?.toLowerCase();
        final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/${ext == 'png' ? 'png' : 'jpeg'}';

        originalFileUrl = await _prescriptionService.uploadPrescriptionFile(
          doctorId: doctorId,
          patientId: currentPatient.id,
          fileName: _pickedFile!.name,
          bytes: _pickedFile!.bytes!,
          mimeType: mimeType,
        );
      }

      final presDateStr = DateUtilsHelper.formatStorageDate(_prescriptionDate);
      final followUpDateStr = DateUtilsHelper.formatStorageDate(_calculatedFollowUpDate);

      await _prescriptionService.savePrescriptionAndScheduleFollowUp(
        doctorId: doctorId,
        patientId: currentPatient.id,
        prescriptionDate: presDateStr,
        source: _pickedFile != null ? 'upload' : 'manual',
        originalFileUrl: originalFileUrl,
        medicines: validMedicines,
        followUpType: _followUpType,
        followUpDate: followUpDateStr,
        aiExtracted: _aiExtracted,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final contactInfo = [
          if (currentPatient.phone != null && currentPatient.phone!.isNotEmpty) 'SMS to ${currentPatient.phone}',
          if (currentPatient.email != null && currentPatient.email!.isNotEmpty) 'Email to ${currentPatient.email}',
        ].join(' & ');

        final msg = contactInfo.isNotEmpty
            ? 'Prescription saved & recall scheduled for $followUpDateStr. Digital summary $contactInfo sent successfully!'
            : 'Prescription saved & recall scheduled for $followUpDateStr.';

        Navigator.pop(context, true);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
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
        _errorMessage = 'Failed to save prescription: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showPatientPickerModal(BuildContext context, List<PatientModel> patients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = patients.where((p) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  (p.phone != null && p.phone!.contains(q)) ||
                  (p.email != null && p.email!.toLowerCase().contains(q));
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Patient',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slateDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search patient by name, mobile, email...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.slateMuted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() => query = val.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_off_outlined, size: 40, color: AppTheme.slateMuted),
                                const SizedBox(height: 8),
                                Text(
                                  query.isEmpty ? 'No registered patients found.' : 'No matching patient found.',
                                  style: const TextStyle(color: AppTheme.slateMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final p = filtered[i];
                              final isSelected = _selectedPatient?.id == p.id;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? AppTheme.primaryNavy : const Color(0xFFEFF6FF),
                                  foregroundColor: isSelected ? Colors.white : AppTheme.primaryNavy,
                                  child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P'),
                                ),
                                title: Text(
                                  p.name,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                subtitle: Text(
                                  [
                                    if (p.phone != null && p.phone!.isNotEmpty) '📱 ${p.phone}',
                                    if (p.email != null && p.email!.isNotEmpty) '✉️ ${p.email}',
                                  ].join('   '),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slateMedium),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppTheme.statusSuccess)
                                    : const Icon(Icons.chevron_right, color: AppTheme.slateMuted),
                                onTap: () {
                                  setState(() => _selectedPatient = p);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctorId = auth.currentUser?.uid ?? '';
    final patientName = _selectedPatient?.name ?? widget.patient?.name ?? 'New Prescription';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Prescription • $patientName',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient selector if not provided
            if (widget.patient == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Patient *',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<PatientModel>>(
                        stream: _patientService.streamPatients(doctorId),
                        builder: (context, snapshot) {
                          final rawPatients = snapshot.data ?? [];
                          final uniqueMap = <String, PatientModel>{};
                          for (final p in rawPatients) {
                            if (p.id.isNotEmpty) uniqueMap[p.id] = p;
                          }
                          final patients = uniqueMap.values.toList();

                          if (_selectedPatient != null) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryNavy,
                                    radius: 18,
                                    child: Text(
                                      _selectedPatient!.name.isNotEmpty ? _selectedPatient!.name[0].toUpperCase() : 'P',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedPatient!.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.slateDark,
                                          ),
                                        ),
                                        if (_selectedPatient!.phone != null || _selectedPatient!.email != null)
                                          Text(
                                            [
                                              if (_selectedPatient!.phone != null) _selectedPatient!.phone,
                                              if (_selectedPatient!.email != null) _selectedPatient!.email,
                                            ].join(' • '),
                                            style: const TextStyle(fontSize: 12, color: AppTheme.slateMedium),
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showPatientPickerModal(context, patients),
                                    icon: const Icon(Icons.edit, size: 14),
                                    label: const Text('Change'),
                                  ),
                                ],
                              ),
                            );
                          }

                          return InkWell(
                            onTap: () => _showPatientPickerModal(context, patients),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderGrey),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person_search_outlined, color: AppTheme.primaryBlue, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Tap to select a registered patient...',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: AppTheme.slateMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: AppTheme.slateDark),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error display
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusDangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.statusDangerBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.statusDanger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(color: AppTheme.statusDanger, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // AI Extracted Review Banner
            if (_aiExtracted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.statusWarningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.statusWarningBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.statusWarning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Extracted Information — Please Review & Confirm',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.slateDark,
                            ),
                          ),
                          if (_aiExtractionNote != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _aiExtractionNote!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.slateMedium),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section 1: Upload / AI Scan Option
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prescription Document (Upload / AI)',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.slateDark),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            'Gemini 1.5 Flash',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Attach a JPG, PNG, or PDF file to auto-extract medicines and auto-calculate follow-up recall dates.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.slateMuted),
                    ),
                    const SizedBox(height: 14),

                    // File picker row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isExtracting ? null : _pickPrescriptionFile,
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: Text(
                              _pickedFile != null ? _pickedFile!.name : 'Choose Prescription File',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isExtracting ? null : _runAiExtraction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: _isExtracting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.auto_awesome, size: 16),
                            label: Text(
                              _isExtracting ? 'Analyzing...' : 'Extract with AI',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Prescription Date
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prescription Issue Date',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateUtilsHelper.formatDisplayDate(_prescriptionDate),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _prescriptionDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _prescriptionDate = picked;
                            _recalculateFollowUp();
                          });
                        }
                      },
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: Text('Change Date', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Medicines Table / List
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prescribed Medications (${_medicines.length})',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.slateDark),
                        ),
                        TextButton.icon(
                          onPressed: () => _addMedicineRow(),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('+ Add Drug', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _medicines.length,
                      separatorBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),
                      itemBuilder: (context, index) {
                        final med = _medicines[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Medicine Name *',
                                    hint: 'e.g. Amoxicillin 500mg',
                                    initialValue: med.name,
                                    onChanged: (v) => med.name = v,
                                  ),
                                ),
                                if (_medicines.length > 1) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.statusDanger, size: 20),
                                    onPressed: () => _removeMedicineRow(index),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Dosage',
                                    hint: '1 tab',
                                    initialValue: med.dosage,
                                    onChanged: (v) => med.dosage = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Frequency',
                                    hint: 'TDS (3x/day)',
                                    initialValue: med.frequency,
                                    onChanged: (v) => med.frequency = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Duration',
                                    hint: '5 days',
                                    initialValue: med.duration,
                                    onChanged: (v) => med.duration = v,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CustomTextField(
                              label: 'Instructions / Notes',
                              hint: 'Take after meals with water',
                              initialValue: med.instructions,
                              onChanged: (v) => med.instructions = v,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Deterministic Follow-up Calculator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alarm_on, color: AppTheme.primaryNavy, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Automatic Follow-up & Recall Interval',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.slateDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Default is +3 months. Select a standard preset or customize recall date.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.slateMuted),
                    ),
                    const SizedBox(height: 14),

                    // Interval Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildIntervalPill('15_days', '15 Days (+15d)'),
                        _buildIntervalPill('1_month', '1 Month (+1m)'),
                        _buildIntervalPill('3_months', '3 Months (Default +3m)'),
                        _buildIntervalPill('6_months', '6 Months (+6m)'),
                        _buildIntervalPill('custom', 'Custom Date...'),
                      ],
                    ),

                    if (_followUpType == 'custom') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _customFollowUpDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              _customFollowUpDate = picked;
                              _recalculateFollowUp();
                            });
                          }
                        },
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(
                          _customFollowUpDate != null
                              ? 'Selected: ${DateUtilsHelper.formatDisplayDate(_customFollowUpDate!)}'
                              : 'Select Custom Date',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Result Calculation Badge
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available, color: AppTheme.statusPurple, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calculated Follow-up Appointment Date:',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.statusPurple, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateUtilsHelper.formatDisplayDate(_calculatedFollowUpDate),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.statusPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            CustomButton(
              text: 'Save Prescription & Schedule Follow-up',
              onPressed: _handleSaveAndSchedule,
              isLoading: _isSaving,
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalPill(String type, String label) {
    final isSelected = _followUpType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _followUpType = type;
          _recalculateFollowUp();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.slateDark,
          ),
        ),
      ),
    );
  }
}
