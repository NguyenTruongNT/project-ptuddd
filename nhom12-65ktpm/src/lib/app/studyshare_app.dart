import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/app_preferences.dart';
import '../design_system/theme/studyshare_theme.dart';
import '../l10n/app_localizations.dart';
import 'app_router.dart';

class StudyShareApp extends ConsumerWidget {
  const StudyShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'StudyShare',
      theme: StudyShareTheme.build(Brightness.light,
          seed: preferences.palette.seed),
      darkTheme: StudyShareTheme.build(Brightness.dark,
          seed: preferences.palette.seed),
      themeMode: preferences.themeMode,
      locale: Locale(preferences.localeCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
