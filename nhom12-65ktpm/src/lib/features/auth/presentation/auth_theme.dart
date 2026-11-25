import 'package:flutter/material.dart';

/// Brand styling stays within Auth; the rest of the app keeps its chosen theme.
abstract final class AuthTheme {
  static const primary = Color(0xFF078333);
  static const softGreen = Color(0xFFF1F8F1);

  static ThemeData apply(ThemeData base, {bool reduceMotion = false}) {
    final dark = base.brightness == Brightness.dark;
    final scheme = base.colorScheme.copyWith(
      primary: dark ? const Color(0xFF88DCA3) : primary,
      onPrimary: dark ? const Color(0xFF10391C) : Colors.white,
      primaryContainer: dark ? const Color(0xFF214D2D) : softGreen,
      onPrimaryContainer: dark
          ? const Color(0xFFBBF1CB)
          : const Color(0xFF17411B),
    );
    final radius = BorderRadius.circular(16);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: dark ? scheme.outline : const Color(0xFFB8C9BC),
      ),
    );
    return base.copyWith(
      colorScheme: scheme,
      textTheme: base.textTheme.apply(fontFamily: 'Inter'),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: dark ? scheme.surfaceContainerLow : const Color(0xFFFAFCFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? scheme.error
                : scheme.primary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 56),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          animationDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .06),
      ),
    );
  }
}
