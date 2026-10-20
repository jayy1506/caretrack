import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'custom_button.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Icon(icon, size: 40, color: AppTheme.slateMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.slateDark,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.slateMuted,
                ),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              CustomButton(
                text: actionText!,
                onPressed: onAction,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
