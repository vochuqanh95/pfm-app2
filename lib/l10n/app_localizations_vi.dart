// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Family Wealth';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsCurrency => 'Tiền tệ';

  @override
  String get languageEnglish => 'Tiếng Anh';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get currencyUsd => 'Đô la Mỹ';

  @override
  String get currencyVnd => 'Việt Nam Đồng';

  @override
  String get chooseLanguage => 'Chọn ngôn ngữ';

  @override
  String get chooseCurrency => 'Chọn tiền tệ';

  @override
  String get languageUpdatedRestartHint => 'Đã cập nhật ngôn ngữ. Một số màn có thể cần mở lại để áp dụng hoàn toàn.';

  @override
  String get currencyUpdated => 'Đã cập nhật tiền tệ';

  @override
  String get sharedLabel => 'Chia sẻ';
}
