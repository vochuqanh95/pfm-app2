import 'package:intl/intl.dart';
import '../enums/app_currency.dart';

class MoneyFormatter {
  static String format(
    num amount, {
    required AppCurrency currency,
  }) {
    if (currency == AppCurrency.vnd) {
      return NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '₫',
        decimalDigits: 0,
      ).format(amount);
    }
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount);
  }
}
