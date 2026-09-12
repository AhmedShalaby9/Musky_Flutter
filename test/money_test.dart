import 'package:flutter_test/flutter_test.dart';
import 'package:musky/core/money.dart';

void main() {
  test('money input uses exact piastres and rejects extra precision', () {
    expect(parseMoney('29.50'), 2950);
    expect(parseMoney('0.1'), 10);
    expect(parseMoney('100'), 10000);
    for (final value in [
      '-1',
      '1.001',
      'NaN',
      '1e4',
      '999999999999999999999',
    ]) {
      expect(parseMoney(value), isNull);
    }
    expect(egp(8850), 'EGP 88.50');
    expect(egp(-123456), '-EGP 1,234.56');
  });
}
