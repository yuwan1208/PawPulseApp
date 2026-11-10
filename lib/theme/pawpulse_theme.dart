
import 'package:flutter/material.dart';

class PawPulseTheme {
  PawPulseTheme._();

  // Main colors
  static const Color primaryCyan = Color(0xFF02F4F4);
  static const Color turquoise = Color(0xFF0AF6E2);
  static const Color lightCyan = Color(0xFFE4FCFC);
  static const Color darkNavy = Color(0xFF17213A);
  static const Color secondaryGray = Color(0xFF777D8D);
  static const Color background = Color(0xFFF7FEFE);
  static const Color white = Colors.white;

  // Main gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      primaryCyan,
      Color.fromARGB(255, 2, 204, 255),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Header gradient
  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      turquoise,
      Color.fromARGB(255, 2, 204, 255),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light gradient for cards and backgrounds
  static const LinearGradient softGradient = LinearGradient(
    colors: [
      lightCyan,
      white,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Reusable border radiuses
  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(20));

  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(14));

  // Reusable card decoration
  static BoxDecoration get gradientCardDecoration {
    return BoxDecoration(
      gradient: softGradient,
      borderRadius: cardRadius,
      boxShadow: [
        BoxShadow(
          color: primaryCyan.withValues(alpha: 0.14),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
