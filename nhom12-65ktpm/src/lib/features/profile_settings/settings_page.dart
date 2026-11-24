import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences/app_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/logout_button.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(appPreferencesProvider);
    final controller = ref.read(appPreferencesProvider.notifier);
    Future<void> save(Future<void> action) async {
      try {
        await action;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.preferencesSaveError)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(l10n.themeLabel, style: Theme.of(context).textTheme.titleMedium),
          DropdownButton<ThemeMode>(
            value: value.themeMode,
            isExpanded: true,
            onChanged: (mode) {
              if (mode != null) save(controller.setThemeMode(mode));
            },
            items: [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(l10n.themeSystem),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(l10n.themeLight),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(l10n.themeDark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.paletteLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: StudySharePalette.values.map((palette) {
              return ChoiceChip(
                label: Text(palette.label),
                selected: value.palette == palette,
                avatar: CircleAvatar(backgroundColor: palette.seed),
                onSelected: (_) => save(controller.setPalette(palette)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.languageLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DropdownButton<String>(
            value: value.localeCode,
            isExpanded: true,
            onChanged: (code) {
              if (code != null) save(controller.setLocale(code));
            },
            items: const [
              DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
          ),
          const Divider(height: 24),
          SwitchListTile(
            title: Text(l10n.gridLabel),
            value: value.showGrid,
            onChanged: (v) => save(controller.setGrid(v)),
          ),
          SwitchListTile(
            title: Text(l10n.leavesLabel),
            subtitle: Text(l10n.leavesHint),
            value: value.showLeaves,
            onChanged: (v) => save(controller.setLeaves(v)),
          ),
          const SizedBox(height: 16),
          const LogoutButton(),
          const SizedBox(height: 16),
          Text(
            l10n.preferencesSavedNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
