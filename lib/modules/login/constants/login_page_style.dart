import 'package:flutter/material.dart';

class LoginPageStyles {
  static const Color lncmisBlue = Color(0xFF0F33A1);
  static const Color lncmisBlueDark = Color(0xFF09246F);
  static const Color lncmisBlueLight = Color(0xFF3E67D6);
  static const Color lncmisBackground = Color(0xFFF4F7FC);
  static const Color lncmisText = Color(0xFF1F2937);
  static const Color lncmisMuted = Color(0xFF64748B);

  static TextStyle formLabelStyle = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: lncmisText,
  );

  static TextStyle formInputValueStyle = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: lncmisText,
  );

  static BoxConstraints loginBoxConstraints = const BoxConstraints(
    maxHeight: 45,
    minHeight: 42,
    maxWidth: 45,
    minWidth: 42,
  );

  static InputDecoration inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
    bool hasError = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: lncmisMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: hasError ? Colors.redAccent : lncmisBlue,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: hasError ? Colors.redAccent.withOpacity(0.45) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: hasError ? Colors.redAccent : lncmisBlue,
          width: 1.4,
        ),
      ),
    );
  }
}
