/// Reads numbers typed the Brazilian way.
abstract final class Parsers {
  static final _thousandsOnly = RegExp(r'^\d{1,3}(\.\d{3})+$');

  /// "1.234,56", "49,90", "49.90", "R$ 1.234" → number. Empty or invalid → null.
  static double? decimal(String text) {
    var value = text.replaceAll(RegExp(r'[R$\s]'), '');
    if (value.isEmpty) return null;
    if (value.contains(',')) {
      // Comma is the decimal separator; dots group thousands.
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (_thousandsOnly.hasMatch(value)) {
      value = value.replaceAll('.', '');
    }
    return double.tryParse(value);
  }

  static int? integer(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'[\s.]'), ''));
}
