import 'dart:convert';

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

  bool sameAs(AppPreferences other) =>
      themeMode == other.themeMode &&
      localeCode == other.localeCode &&
      palette == other.palette &&
      showGrid == other.showGrid &&
      showLeaves == other.showLeaves;

  Map<String, Object> toJson() => {
    'theme': themeMode.name,
    'locale': localeCode,
    'palette': palette.name,
    'grid': showGrid,
    'leaves': showLeaves,
  };

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

enum PreferencesSavePhase { idle, saving, saved, failed }

class PreferencesSaveState {
  const PreferencesSaveState(this.phase, {this.revision = 0});
  final PreferencesSavePhase phase;
  final int revision;
}

final preferencesSaveStateProvider =
    NotifierProvider<PreferencesSaveController, PreferencesSaveState>(
      PreferencesSaveController.new,
    );

class PreferencesSaveController extends Notifier<PreferencesSaveState> {
  @override
  PreferencesSaveState build() =>
      const PreferencesSaveState(PreferencesSavePhase.idle);

  void update(PreferencesSavePhase phase, int revision) {
    state = PreferencesSaveState(phase, revision: revision);
  }
}

class AppPreferencesController extends Notifier<AppPreferences> {
  late AppPreferences _persisted;
  int _revision = 0;

  @override
  AppPreferences build() {
    final store = ref.watch(preferencesStoreProvider);
    Map<String, dynamic> saved = {};
    try {
      final decoded = jsonDecode(store?.getString('ui.preferences.v1') ?? '{}');
      if (decoded is Map<String, dynamic>) saved = decoded;
    } on FormatException {
      /* Fall back to legacy keys. */
    }
    String? text(String key) => saved[key] is String
        ? saved[key] as String
        : store?.getString('ui.$key');
    bool boolean(String key) => saved[key] is bool
        ? saved[key] as bool
        : store?.getBool('ui.$key') ?? true;
    return _persisted = AppPreferences(
      themeMode:
          ThemeMode.values.where((v) => v.name == text('theme')).firstOrNull ??
          ThemeMode.system,
      palette:
          StudySharePalette.values
              .where((v) => v.name == text('palette'))
              .firstOrNull ??
          StudySharePalette.green,
      localeCode: text('locale') == 'en' ? 'en' : 'vi',
      showGrid: boolean('grid'),
      showLeaves: boolean('leaves'),
    );
  }

  Future<void> _pending = Future.value();
  Future<void> _save(AppPreferences Function(AppPreferences) change) {
    final next = change(state);
    if (next.sameAs(state)) return Future.value();
    final revision = ++_revision;
    final store = ref.read(preferencesStoreProvider);
    final progress = ref.read(preferencesSaveStateProvider.notifier);
    // Apply first. Capture the complete selection so rapid edits never lose fields.
    state = next;
    progress.update(PreferencesSavePhase.saving, revision);
    final operation = _pending.then((_) async {
      try {
        if (store != null) {
          final saved = await store.setString(
            'ui.preferences.v1',
            jsonEncode(next.toJson()),
          );
          if (!saved) throw StateError('Preferences were not saved');
        }
        _persisted = next;
        if (revision == _revision && ref.mounted) {
          progress.update(PreferencesSavePhase.saved, revision);
        }
      } catch (_) {
        // An older failed write must not replace a newer choice on screen.
        if (revision == _revision && ref.mounted) {
          state = _persisted;
          progress.update(PreferencesSavePhase.failed, revision);
        }
        rethrow;
      }
    });
    // Keep the queue usable after failures; each caller still receives its error.
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _save((s) => s.copyWith(themeMode: mode));
  Future<void> setLocale(String code) {
    if (code != 'vi' && code != 'en') throw ArgumentError('locale');
    return _save((s) => s.copyWith(localeCode: code));
  }

  Future<void> setPalette(StudySharePalette palette) =>
      _save((s) => s.copyWith(palette: palette));
  Future<void> setGrid(bool visible) =>
      _save((s) => s.copyWith(showGrid: visible));
  Future<void> setLeaves(bool visible) =>
      _save((s) => s.copyWith(showLeaves: visible));

  Future<void> savePreferences(AppPreferences value) {
    if (value.localeCode != 'vi' && value.localeCode != 'en') {
      throw ArgumentError('locale');
    }
    return _save((_) => value);
  }
}
