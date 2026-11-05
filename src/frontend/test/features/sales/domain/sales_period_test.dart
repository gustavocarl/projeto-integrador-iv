import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_period.dart';

void main() {
  // A Thursday.
  final reference = DateTime(2026, 11, 5, 15, 30);

  test('day, week (Monday to Sunday) and month around a date', () {
    expect(
      SalesPeriod.of(PeriodKind.day, reference),
      SalesPeriod(DateTime(2026, 11, 5), DateTime(2026, 11, 5)),
    );
    expect(
      SalesPeriod.of(PeriodKind.week, reference),
      SalesPeriod(DateTime(2026, 11, 2), DateTime(2026, 11, 8)),
    );
    expect(
      SalesPeriod.of(PeriodKind.month, reference),
      SalesPeriod(DateTime(2026, 11), DateTime(2026, 11, 30)),
    );
  });

  test('a week can cross months; Sunday stays in its own week', () {
    expect(
      SalesPeriod.of(PeriodKind.week, DateTime(2026, 11, 1)),
      SalesPeriod(DateTime(2026, 10, 26), DateTime(2026, 11, 1)),
    );
  });

  test('labels and file names match the backend', () {
    final day = SalesPeriod.of(PeriodKind.day, reference);
    final week = SalesPeriod.of(PeriodKind.week, reference);
    final month = SalesPeriod.of(PeriodKind.month, DateTime(2026, 2, 10));

    expect((day.label, day.fileName), ('05/11/2026', 'vendas-2026-11-05.xlsx'));
    expect(
      (week.label, week.fileName),
      ('02/11/2026 a 08/11/2026', 'vendas-2026-11-02-a-2026-11-08.xlsx'),
    );
    expect(
      (month.label, month.fileName),
      ('fevereiro/2026', 'vendas-2026-02.xlsx'),
    );
    expect(SalesPeriod.apiDate(DateTime(2026, 2, 3)), '2026-02-03');
  });
}
