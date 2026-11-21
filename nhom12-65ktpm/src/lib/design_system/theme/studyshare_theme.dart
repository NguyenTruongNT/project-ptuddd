import 'package:flutter/material.dart';

class StudyShareTheme {
  const StudyShareTheme._();

  static const brandGreen = Color(0xFF0FA241);
  static const darkGreen = Color(0xFF17411B);
  static const lime = Color(0xFFECF665);
  static const lightCanvas = Color(0xFFF8FCF7);

  static ThemeData build(Brightness brightness, {Color seed = brandGreen}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? lightCanvas
          : colorScheme.surface,
      visualDensity: VisualDensity.standard,
    );
  }
}
