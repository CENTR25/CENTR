import 'package:flutter/material.dart';

import '../../../../core/theme/theme_redesign.dart';

/// Pill text field matching the Figma input token:
/// fill rgba(255,255,255,0.15), radius 40, height 54, no leading icon by default.
class RedesignTextField extends StatelessWidget {
  const RedesignTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: RedesignType.bodySm.copyWith(color: RedesignColors.neutral100),
        prefixIcon: prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 20, right: 12),
                child: Icon(prefixIcon, color: RedesignColors.primario400, size: 20),
              ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: RedesignSpacing.inputHeight,
        ),
        suffixIcon: suffixIcon != null
            ? Padding(padding: const EdgeInsets.only(right: 16), child: suffixIcon)
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: RedesignSpacing.inputHeight,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: RedesignColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RedesignSpacing.inputPaddingH,
          vertical: RedesignSpacing.inputPaddingV,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.input),
          borderSide: const BorderSide(color: RedesignColors.inputBorderFocused, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.input),
          borderSide: const BorderSide(color: RedesignColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.input),
          borderSide: const BorderSide(color: RedesignColors.danger, width: 1),
        ),
        errorStyle: RedesignType.label.copyWith(color: RedesignColors.peligro300),
      ),
    );
  }
}
