import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../core/preferences/app_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/auth_page_layout.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Widget _section(
    BuildContext context,
    IconData icon,
    String title,
    List<Widget> children,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final value = ref.watch(appPreferencesProvider);
    final progress = ref.watch(preferencesSaveStateProvider);
    final controller = ref.read(appPreferencesProvider.notifier);
    // The app-level feedback handles failures even after this page is closed.
    void apply(Future<void> operation) {
      operation.catchError((Object _) {});
    }

    final palettes = {
      StudySharePalette.green: text.paletteGreen,
      StudySharePalette.blue: text.paletteBlue,
      StudySharePalette.purple: text.palettePurple,
      StudySharePalette.orange: text.paletteOrange,
    };
    final saving = progress.phase == PreferencesSavePhase.saving;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: text.commonBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.profile);
            }
          },
        ),
        title: Text(text.settingsTitle),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('settings-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.settingsSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  progress.phase == PreferencesSavePhase.failed
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  size: 18,
                                  color:
                                      progress.phase ==
                                          PreferencesSavePhase.failed
                                      ? scheme.error
                                      : scheme.primary,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            switch (progress.phase) {
                              PreferencesSavePhase.saving =>
                                text.preferencesSaving,
                              PreferencesSavePhase.saved =>
                                text.preferencesSaved,
                              PreferencesSavePhase.failed =>
                                text.preferencesSaveRestored,
                              PreferencesSavePhase.idle =>
                                text.preferencesAutoSaveHint,
                            },
                            key: const ValueKey('settings-save-status'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color:
                                      progress.phase ==
                                          PreferencesSavePhase.failed
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _section(
                    context,
                    Icons.palette_outlined,
                    text.settingsAppearance,
                    [
                      Text(
                        text.themeLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            SegmentedButton<ThemeMode>(
                              direction:
                                  constraints.maxWidth < 350 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          18
                                  ? Axis.vertical
                                  : Axis.horizontal,
                              expandedInsets:
                                  constraints.maxWidth < 350 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          18
                                  ? null
                                  : EdgeInsets.zero,
                              segments: [
                                for (final item in [
                                  (
                                    ThemeMode.system,
                                    Icons.brightness_auto_outlined,
                                    text.themeSystem,
                                  ),
                                  (
                                    ThemeMode.light,
                                    Icons.light_mode_outlined,
                                    text.themeLight,
                                  ),
                                  (
                                    ThemeMode.dark,
                                    Icons.dark_mode_outlined,
                                    text.themeDark,
                                  ),
                                ])
                                  ButtonSegment(
                                    value: item.$1,
                                    icon: Icon(item.$2, size: 18),
                                    label: Text(
                                      item.$3,
                                      key: ValueKey('theme-${item.$1.name}'),
                                    ),
                                  ),
                              ],
                              selected: {value.themeMode},
                              style: SegmentedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onSelectionChanged: (selection) => apply(
                                controller.setThemeMode(selection.first),
                              ),
                            ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        text.paletteLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final palette in StudySharePalette.values)
                            ChoiceChip(
                              key: ValueKey('palette-${palette.name}'),
                              label: Text(palettes[palette]!),
                              selected: value.palette == palette,
                              avatar: CircleAvatar(
                                backgroundColor: palette.seed,
                                child: value.palette == palette
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              showCheckmark: false,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              onSelected: (_) =>
                                  apply(controller.setPalette(palette)),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    context,
                    Icons.language_outlined,
                    text.languageLabel,
                    [
                      DropdownButtonFormField<String>(
                        key: ValueKey('language-${value.localeCode}'),
                        initialValue: value.localeCode,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: InputDecoration(
                          labelText: text.languageLabel,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'vi',
                            child: Text('Tiếng Việt'),
                          ),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (code) {
                          if (code != null) apply(controller.setLocale(code));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    context,
                    Icons.auto_awesome_outlined,
                    text.settingsEffects,
                    [
                      SwitchListTile.adaptive(
                        key: const ValueKey('settings-grid'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(text.gridLabel),
                        subtitle: Text(text.gridHint),
                        value: value.showGrid,
                        onChanged: (v) => apply(controller.setGrid(v)),
                      ),
                      const Divider(height: 24),
                      SwitchListTile.adaptive(
                        key: const ValueKey('settings-leaves'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(text.leavesLabel),
                        subtitle: Text(text.leavesHint),
                        value: value.showLeaves,
                        onChanged: (v) => apply(controller.setLeaves(v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (progress.phase == PreferencesSavePhase.failed)
                    AuthMessage(text.preferencesSaveRestored, error: true),
                  Text(
                    text.preferencesAutoSaveHint,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
