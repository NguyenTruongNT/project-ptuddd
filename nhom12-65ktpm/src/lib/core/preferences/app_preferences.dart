import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      AppPreferencesController.new,
    );

// Được nạp trước runApp để theme/locale không nháy về giá trị mặc định.
final preferencesStoreProvider = Provider<SharedPreferences?>((ref) => null);

class AppPreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() {
    final store = ref.watch(preferencesStoreProvider);
    return AppPreferences(
      themeMode:
          ThemeMode.values
              .where((v) => v.name == store?.getString('ui.theme'))
              .firstOrNull ??
          ThemeMode.system,
      palette:
          StudySharePalette.values
              .where((v) => v.name == store?.getString('ui.palette'))
              .firstOrNull ??
          StudySharePalette.green,
      localeCode: store?.getString('ui.locale') == 'en' ? 'en' : 'vi',
      showGrid: store?.getBool('ui.grid') ?? true,
      showLeaves: store?.getBool('ui.leaves') ?? true,
    );
  }

  Future<void> _pending = Future.value();
  Future<void> _save(
    String key,
    Object value,
    AppPreferences Function(AppPreferences) change,
  ) {
    // Tuần tự hóa thao tác để đổi theme + locale nhanh không ghi đè nhau.
    _pending = _pending.catchError((Object _) {}).then((_) async {
      final store = ref.read(preferencesStoreProvider);
      if (store != null) {
        final saved = value is bool
            ? await store.setBool(key, value)
            : await store.setString(key, value as String);
        if (!saved) throw StateError('Preferences were not saved');
      }
      state = change(state);
    });
    return _pending;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _save('ui.theme', mode.name, (s) => s.copyWith(themeMode: mode));
  Future<void> setLocale(String code) {
    if (code != 'vi' && code != 'en') throw ArgumentError('locale');
    return _save('ui.locale', code, (s) => s.copyWith(localeCode: code));
  }

  Future<void> setPalette(StudySharePalette palette) =>
      _save('ui.palette', palette.name, (s) => s.copyWith(palette: palette));
  Future<void> setGrid(bool visible) =>
      _save('ui.grid', visible, (s) => s.copyWith(showGrid: visible));
  Future<void> setLeaves(bool visible) =>
      _save('ui.leaves', visible, (s) => s.copyWith(showLeaves: visible));
}
