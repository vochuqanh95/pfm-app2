import 'package:equatable/equatable.dart';
import '../enums/app_currency.dart';
import '../enums/app_language.dart';

class AppSettings extends Equatable {
  final AppLanguage language;
  final AppCurrency currency;

  const AppSettings({
    this.language = AppLanguage.english,
    this.currency = AppCurrency.usd,
  });

  AppSettings copyWith({
    AppLanguage? language,
    AppCurrency? currency,
  }) {
    return AppSettings(
      language: language ?? this.language,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language.code,
        'currency': currency.code,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    return AppSettings(
      language: AppLanguage.fromCode(json['language'] as String? ?? 'en'),
      currency: AppCurrency.fromCode(json['currency'] as String? ?? 'USD'),
    );
  }

  @override
  List<Object> get props => [language, currency];
}
