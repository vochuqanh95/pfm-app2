enum AppCurrency {
  usd('USD'),
  vnd('VND');

  final String code;
  const AppCurrency(this.code);

  static AppCurrency fromCode(String? code) {
    switch (code) {
      case 'VND':
        return AppCurrency.vnd;
      case 'USD':
      default:
        return AppCurrency.usd;
    }
  }
}
