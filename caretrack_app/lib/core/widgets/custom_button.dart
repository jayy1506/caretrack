import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, danger }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonVariant variant;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppTheme.primaryNavy;
    Color fg = Colors.white;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case ButtonVariant.primary:
        bg = AppTheme.primaryNavy;
        fg = Colors.white;
        break;
      case ButtonVariant.secondary:
        bg = AppTheme.primaryBlue;
        fg = Colors.white;
        break;
      case ButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppTheme.slateDark;
        border = const BorderSide(color: AppTheme.borderGrey, width: 1.5);
        break;
      case ButtonVariant.danger:
        bg = AppTheme.statusDangerBg;
        fg = AppTheme.statusDanger;
        border = Border.all(color: AppTheme.statusDanger.withValues(alpha: 0.3), width: 1).top;
        break;
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
