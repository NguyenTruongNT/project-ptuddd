// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navPublish => 'Post';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navProfile => 'Profile';

  @override
  String get welcomeMessage =>
      'Welcome to StudyShare. Business features will be implemented in subsequent pull requests.';

  @override
  String get placeholderMessage =>
      'Foundation placeholder; no Supabase connection or transaction actions yet.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLabel => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get paletteLabel => 'Color palette';

  @override
  String get languageLabel => 'Language';

  @override
  String get gridLabel => 'Grid paper background';

  @override
  String get leavesLabel => 'Falling leaves';

  @override
  String get leavesHint => 'Home only; hidden when reduced motion is enabled.';

  @override
  String get sessionOnlyNotice =>
      'Prototype: choices are stored in memory only. Local persistence will be added in a later task.';
}
