import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

void main() {
  group('units', () {
    test('every unit converts to its base', () {
      expect(units['km']!.toBase(1), 1000);
      expect(units['au']!.toBase(1), closeTo(1.496e11, 1e8));
      expect(units['yr']!.toBase(1), 31557600);
      expect(units['km/h']!.toBase(36), closeTo(10, 1e-9));
      expect(units['lb']!.fromBase(0.45359237), closeTo(1, 1e-12));
    });

    test('currencies are not compatible with each other', () {
      expect(units['USD']!.isCompatibleWith(units['EUR']!), isFalse);
      expect(units['km']!.isCompatibleWith(units['mi']!), isTrue);
      expect(units['km']!.isCompatibleWith(units['kg']!), isFalse);
    });
  });

  group('formatNumber', () {
    test('exact integers get separators', () {
      expect(formatNumber(42), '42');
      expect(formatNumber(384400), '384,400');
      expect(formatNumber(-12104), '-12,104');
    });

    test('decimals keep three significant digits', () {
      expect(formatNumber(0.1), '0.1');
      expect(formatNumber(3.14159), '3.14');
      expect(formatNumber(1234.5678), '1,235');
      expect(formatNumber(0.0025), '0.0025');
    });

    test('large values use words, then scientific notation', () {
      expect(formatNumber(4.5e9), '4.5 billion');
      expect(formatNumber(1.2e6), '1.2 million');
      expect(formatNumber(7.9e12), '7.9 trillion');
      expect(formatNumber(4.398e15), '4.4 × 10¹⁵');
      expect(formatNumber(1e-6), '1 × 10⁻⁶');
      expect(formatNumber(9.9999e20), '1 × 10²¹');
    });

    test('handles zero and non-finite values', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(double.infinity), '∞');
      expect(formatNumber(double.nan), '—');
    });
  });

  group('formatting quantities', () {
    test('formatQuantity adds symbols and approximation', () {
      expect(formatQuantity(384400, units['km']!), '384,400 km');
      expect(formatQuantity(150, units['t']!, approximate: true), '~150 t');
      expect(formatQuantity(2, units['ratio']!), '2×');
      expect(formatQuantity(42, units['count']!), '42');
    });

    test('formatSi picks a readable unit', () {
      expect(formatSi(3.844e8, Dimension.length), '384,400 km');
      expect(formatSi(1e-4, Dimension.length), '0.1 mm');
      expect(formatSi(1.496e11, Dimension.length), '1 AU');
      expect(formatSi(150000, Dimension.mass), '150 t');
      expect(formatSi(7200, Dimension.duration), '2 h');
      expect(formatSi(0, Dimension.length), '0 m');
      expect(formatSi(0, Dimension.length, fallback: units['km']), '0 km');
    });
  });
}
