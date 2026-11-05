import '../../../../core/utils/formatters.dart';

/// How the sales spreadsheet period is chosen.
enum PeriodKind {
  day('Dia'),
  week('Semana'),
  month('Mês'),
  custom('Período');

  const PeriodKind(this.label);

  final String label;
}

/// A range of days (both ends included) for the sales spreadsheet.
class SalesPeriod {
  SalesPeriod(DateTime start, DateTime end)
    : start = _day(start),
      end = _day(end);

  /// The day, its week (Monday to Sunday) or its month. [PeriodKind.custom] starts as the single day.
  factory SalesPeriod.of(PeriodKind kind, DateTime reference) {
    final day = _day(reference);
    return switch (kind) {
      PeriodKind.day || PeriodKind.custom => SalesPeriod(day, day),
      PeriodKind.week => SalesPeriod(
        day.subtract(Duration(days: day.weekday - DateTime.monday)),
        day.add(Duration(days: DateTime.sunday - day.weekday)),
      ),
      PeriodKind.month => SalesPeriod(
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1, 0),
      ),
    };
  }

  final DateTime start;
  final DateTime end;

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool get _isDay => start == end;

  bool get _isWholeMonth =>
      start.day == 1 && end == DateTime(start.year, start.month + 1, 0);

  /// "05/11/2026", "novembro/2026" (a whole month) or "02/11/2026 a 08/11/2026".
  String get label => _isDay
      ? Formatters.date(start)
      : _isWholeMonth
      ? Formatters.monthYear(start)
      : '${Formatters.date(start)} a ${Formatters.date(end)}';

  /// Same names the backend gives: "vendas-2026-11-05.xlsx", "vendas-2026-11.xlsx",
  /// "vendas-2026-11-02-a-2026-11-08.xlsx".
  String get fileName => _isDay
      ? 'vendas-${apiDate(start)}.xlsx'
      : _isWholeMonth
      ? 'vendas-${apiDate(start).substring(0, 7)}.xlsx'
      : 'vendas-${apiDate(start)}-a-${apiDate(end)}.xlsx';

  /// "2026-11-05", as the API expects.
  static String apiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is SalesPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
