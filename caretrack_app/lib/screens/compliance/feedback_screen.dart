import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';

class FeedbackScreen extends StatefulWidget {
  final String clinicId;

  const FeedbackScreen({super.key, this.clinicId = 'default-clinic'});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _commentController = TextEditingController();
  int _rating = 5;
  String _category = 'workflow';
  bool _isSubmitting = false;

  final Map<String, String> _categoryLabels = {
    'workflow': 'Clinical Workflow & Plans',
    'reminder': 'WhatsApp & SMS Reminders',
    'ai_suggestion': 'AI Prescription & Safety Flags',
    'booking': 'Slot Booking & Front Desk',
    'other': 'General Feedback / Improvement',
  };

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback comments.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('feedback').insert({
        'clinic_id': widget.clinicId,
        'rating': _rating,
        'comment': '[$_category] $comment',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been recorded for the pilot review.'),
            backgroundColor: AppTheme.statusConfirmedText,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e'), backgroundColor: AppTheme.statusMissedText),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Pilot Feedback'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help Improve CareTrack',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your input during the clinical pilot helps us refine reminder timings, appointment workflows, and clinical safety suggestions.',
                    style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rating
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = starIndex),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Category
            const Text('Feedback Topic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _categoryLabels.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 20),

            // Comment
            const Text('Your Observations & Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share what worked well, what was confusing, or suggestions for clinic staff...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 28),

            CustomButton(
              text: 'Submit Feedback',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
