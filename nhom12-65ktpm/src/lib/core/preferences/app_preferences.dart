import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/studyshare_theme.dart';

enum StudySharePalette {
  green('Xanh lá', StudyShareTheme.brandGreen),
  blue('Xanh dương', Color(0xFF2563EB)),
  purple('Tím', Color(0xFF7C3AED)),
  orange('Cam', Color(0xFFEA580C));

  const StudySharePalette(this.label, this.seed);
  final String label;
  final Color seed;
}

class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.localeCode = 'vi',
    this.palette = StudySharePalette.green,
    this.showGrid = true,
    this.showLeaves = true,
  });

  final ThemeMode themeMode;
  final String localeCode;
  final StudySharePalette palette;
  final bool showGrid;
  final bool showLeaves;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    StudySharePalette? palette,
    bool? showGrid,
    bool? showLeaves,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
      palette: palette ?? this.palette,
      showGrid: showGrid ?? this.showGrid,
      showLeaves: showLeaves ?? this.showLeaves,
    );
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
        AppPreferencesController.new);

class AppPreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setLocale(String code) => state = state.copyWith(localeCode: code);
  void setPalette(StudySharePalette palette) =>
      state = state.copyWith(palette: palette);
  void setGrid(bool visible) => state = state.copyWith(showGrid: visible);
  void setLeaves(bool visible) => state = state.copyWith(showLeaves: visible);
}
