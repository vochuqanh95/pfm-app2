// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Family Wealth';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageVietnamese => 'Vietnamese';

  @override
  String get currencyUsd => 'US Dollar';

  @override
  String get currencyVnd => 'Vietnamese Dong';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get chooseCurrency => 'Choose currency';

  @override
  String get languageUpdatedRestartHint =>
      'Language updated. Some screens may need reopening to fully refresh.';

  @override
  String get currencyUpdated => 'Currency updated';

  @override
  String get sharedLabel => 'Shared';
}
