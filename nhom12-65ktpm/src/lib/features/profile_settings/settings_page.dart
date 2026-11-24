import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../core/preferences/app_preferences.dart';
import '../../design_system/widgets/study_confirm.dart';
import '../../design_system/widgets/study_feedback.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/auth_page_layout.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late AppPreferences _draft;
  bool _busy = false;
  bool _leaving = false;
  bool _allowPop = false;
  String? _error;
  bool get _dirty => !_draft.sameAs(ref.read(appPreferencesProvider));
  @override
  void initState() {
    super.initState();
    _draft = ref.read(appPreferencesProvider);
  }

  Future<bool> _discard() async {
    final text = AppLocalizations.of(context)!;
    return !_dirty ||
        await showStudyConfirm(
          context,
          title: text.commonDiscardTitle,
          message: text.commonDiscardBody,
          confirmLabel: text.commonDiscard,
          destructive: true,
        );
  }

  Future<void> _back() async {
    if (_busy || _leaving) return;
    _leaving = true;
    if (await _discard() && mounted) {
      setState(() => _allowPop = true);
      // Rebuild PopScope before asking GoRouter to pop the page.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.profile);
        }
      }
    }
    _leaving = false;
  }

  Future<void> _cancel() async {
    if (_busy || _leaving) return;
    _leaving = true;
    if (await _discard() && mounted) {
      setState(() {
        _draft = ref.read(appPreferencesProvider);
        _error = null;
      });
    }
    _leaving = false;
  }

  Future<void> _save() async {
    if (_busy || !_dirty) return;
    final text = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await showStudyConfirm(
        context,
        title: text.settingsConfirm,
        message: text.settingsConfirmBody,
        confirmLabel: text.profileSave,
        icon: Icons.tune,
      );
      if (!confirmed || !mounted) return;
      await ref.read(appPreferencesProvider.notifier).savePreferences(_draft);
      final updatedText = await AppLocalizations.delegate.load(
        Locale(_draft.localeCode),
      );
      if (mounted) {
        StudyFeedbackHost.of(context)?.show(updatedText.preferencesSaved);
      }
    } catch (_) {
      if (mounted) setState(() => _error = text.preferencesSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _update(AppPreferences next) {
    if (!_busy) {
      setState(() {
        _draft = next;
        _error = null;
      });
    }
  }

  Widget _section(IconData icon, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    ref.watch(appPreferencesProvider);
    final dirty = _dirty;
    final palettes = {
      StudySharePalette.green: text.paletteGreen,
      StudySharePalette.blue: text.paletteBlue,
      StudySharePalette.purple: text.palettePurple,
      StudySharePalette.orange: text.paletteOrange,
    };
    return PopScope(
      canPop: _allowPop || (!dirty && !_busy),
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _busy ? null : _back,
            tooltip: text.commonBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(text.settingsTitle),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                    const SizedBox(height: 24),
                    _section(Icons.palette_outlined, text.settingsAppearance, [
                      Text(
                        text.themeLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
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
                            ChoiceChip(
                              key: ValueKey('theme-${item.$1.name}'),
                              label: Text(item.$3),
                              avatar: Icon(item.$2, size: 18),
                              showCheckmark: false,
                              selected: _draft.themeMode == item.$1,
                              onSelected: _busy
                                  ? null
                                  : (_) => _update(
                                      _draft.copyWith(themeMode: item.$1),
                                    ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                              selected: _draft.palette == palette,
                              avatar: CircleAvatar(
                                backgroundColor: palette.seed,
                                child: _draft.palette == palette
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              showCheckmark: false,
                              onSelected: _busy
                                  ? null
                                  : (_) => _update(
                                      _draft.copyWith(palette: palette),
                                    ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                            ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _section(Icons.language_outlined, text.languageLabel, [
                      DropdownButtonFormField<String>(
                        key: ValueKey('language-${_draft.localeCode}'),
                        initialValue: _draft.localeCode,
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
                        onChanged: _busy
                            ? null
                            : (code) {
                                if (code != null) {
                                  _update(_draft.copyWith(localeCode: code));
                                }
                              },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _section(
                      Icons.auto_awesome_outlined,
                      text.settingsEffects,
                      [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(text.gridLabel),
                          subtitle: Text(text.gridHint),
                          value: _draft.showGrid,
                          onChanged: _busy
                              ? null
                              : (v) => _update(_draft.copyWith(showGrid: v)),
                        ),
                        const Divider(height: 24),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(text.leavesLabel),
                          subtitle: Text(text.leavesHint),
                          value: _draft.showLeaves,
                          onChanged: _busy
                              ? null
                              : (v) => _update(_draft.copyWith(showLeaves: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            text.settingsDraftHint,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) AuthMessage(_error!, error: true),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: dirty && !_busy ? _cancel : null,
                          child: Text(text.commonCancel),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('settings-save'),
                          onPressed: dirty && !_busy ? _save : null,
                          icon: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check, size: 20),
                          label: Text(text.profileSave),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
