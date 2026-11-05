import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/utils/parsers.dart';

void main() {
  test('decimal reads Brazilian and dot-decimal numbers', () {
    expect(Parsers.decimal('49,90'), 49.9);
    expect(Parsers.decimal('1.234,56'), 1234.56);
    expect(Parsers.decimal(r'R$ 1.234,56'), 1234.56);
    expect(Parsers.decimal('49.90'), 49.9);
    expect(Parsers.decimal('1.234'), 1234); // dots grouping thousands
    expect(Parsers.decimal('1.5'), 1.5);
    expect(Parsers.decimal('10'), 10);
  });

  test('decimal: empty or unreadable is null', () {
    expect(Parsers.decimal(''), isNull);
    expect(Parsers.decimal('  '), isNull);
    expect(Parsers.decimal('abc'), isNull);
  });

  test('integer', () {
    expect(Parsers.integer(' 3 '), 3);
    expect(Parsers.integer('1.000'), 1000);
    expect(Parsers.integer('2,5'), isNull);
    expect(Parsers.integer(''), isNull);
  });
}
