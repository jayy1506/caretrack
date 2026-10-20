import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? initialValue;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.slateDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.slateDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
