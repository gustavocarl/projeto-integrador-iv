import '../../../core/utils/formatters.dart';
import '../domain/entities/sales_import.dart';

/// What the charts measure.
enum SalesMetric {
  revenue('Faturamento'),
  sales('Vendas'),
  quantity('Itens');

  const SalesMetric(this.label);

  final String label;

  double valueOf(SalesTotals item) => switch (this) {
    revenue => item.revenue,
    sales => item.sales.toDouble(),
    quantity => item.quantity.toDouble(),
  };

  String format(double value) => switch (this) {
    revenue => Formatters.currency(value),
    sales => '${Formatters.integer(value)} vendas',
    quantity => '${Formatters.integer(value)} itens',
  };

  /// For averages, which are rarely whole numbers: "4,6 vendas".
  String formatAverage(double value) => switch (this) {
    revenue => Formatters.currency(value),
    sales => '${Formatters.decimal(value)} vendas',
    quantity => '${Formatters.decimal(value)} itens',
  };

  String formatAxis(double value) => this == revenue
      ? Formatters.compactCurrency(value)
      : Formatters.compactInteger(value);

  String formatOf(SalesTotals item) => format(valueOf(item));

  /// The metrics other than this one, so a legend doesn't repeat the main value.
  String others(SalesTotals item) => [
    for (final m in values)
      if (m != this) m.formatOf(item),
  ].join(' · ');

  static String all(SalesTotals item) =>
      [for (final m in values) m.formatOf(item)].join(' · ');
}
