enum AppLanguage {
  english('en'),
  vietnamese('vi');

  final String code;
  const AppLanguage(this.code);

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'vi':
        return AppLanguage.vietnamese;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}
