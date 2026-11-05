import 'package:intl/intl.dart';

/// Brazilian formats used across the app.
abstract final class Formatters {
  static final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
  );
  static final _compactCurrency = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: r'R$',
  );
  static final _compactInteger = NumberFormat.compact(locale: 'pt_BR');
  static final _integer = NumberFormat.decimalPattern('pt_BR');
  static final _percent = NumberFormat.decimalPercentPattern(
    locale: 'pt_BR',
    decimalDigits: 1,
  );
  static final _decimal = NumberFormat('#,##0.0', 'pt_BR');
  static final _amount = NumberFormat('0.00', 'pt_BR');
  static final _date = DateFormat('dd/MM/yyyy');
  static final _dayMonth = DateFormat('dd/MM');

  // Without locale data loaded, DateFormat only knows English day names.
  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String currency(num value) => _currency.format(value);
  static String integer(num value) => _integer.format(value);

  /// Short form for chart axes: "R$ 5 mil".
  static String compactCurrency(num value) =>
      value == 0 ? r'R$ 0' : _compactCurrency.format(value);

  /// Short form for chart axes: "1,2 mil".
  static String compactInteger(num value) => _compactInteger.format(value);
  static String percent(double ratio) => _percent.format(ratio);

  /// Growth with its sign: "+12,3%", "−8,0%", "0,0%".
  static String signedPercent(double ratio) {
    final text = _percent.format(ratio.abs());
    if (text == _percent.format(0)) return text;
    return ratio > 0 ? '+$text' : '−$text';
  }

  static String date(DateTime value) => _date.format(value);

  /// One decimal place, for averages: "4,6".
  static String decimal(num value) => _decimal.format(value);

  /// For a price field the user will edit: "6499,90" (no thousands dots, no symbol).
  static String amount(num value) => _amount.format(value);

  /// "12/09".
  static String dayMonth(DateTime value) => _dayMonth.format(value);

  /// "outubro/2026".
  static String monthYear(DateTime value) =>
      '${_months[value.month - 1]}/${value.year}';

  /// Chart axes: "out/26".
  static String shortMonthYear(DateTime value) =>
      '${_months[value.month - 1].substring(0, 3)}/${value.year % 100}';

  /// "sáb, 12/09".
  static String weekdayDate(DateTime value) =>
      '${_weekdays[value.weekday - 1]}, ${dayMonth(value)}';
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
}
