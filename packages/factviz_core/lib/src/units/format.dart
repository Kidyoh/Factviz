import 'dart:math' as math;

import 'units.dart';

const _superscripts = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', //
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
};

const _words = [
  (1e12, 'trillion'),
  (1e9, 'billion'),
  (1e6, 'million'),
];

/// Formats a number for humans: exact integers with thousands separators,
/// "4.5 billion" for large values, and scientific notation beyond that.
String formatNumber(double value, {int significant = 3}) {
  if (value.isNaN) return '—';
  if (value.isInfinite) return value > 0 ? '∞' : '-∞';
  if (value == 0) return '0';
  final sign = value < 0 ? '-' : '';
  final v = value.abs();

  if (v >= 1e15 || v < 1e-3) {
    final exp = (math.log(v) / math.ln10).floor();
    final mantissa = _trim((v / math.pow(10.0, exp)).toStringAsFixed(significant - 1));
    // Rounding can produce "10" (e.g. 9.999e5); renormalise.
    if (mantissa == '10') return '${sign}1 × 10${_sup(exp + 1)}';
    return '$sign$mantissa × 10${_sup(exp)}';
  }
  for (final (scale, word) in _words) {
    if (v >= scale) return '$sign${_trim(_sig(v / scale, significant))} $word';
  }
  if (v == v.roundToDouble()) return '$sign${_group(v.toInt())}';
  final s = _sig(v, significant);
  final parts = s.split('.');
  final grouped = _group(int.parse(parts[0]));
  return '$sign${parts.length == 2 ? _trim('$grouped.${parts[1]}') : grouped}';
}

/// Formats a value in a known unit, e.g. `384,400 km`.
String formatQuantity(double value, Unit unit, {bool approximate = false}) {
  final n = formatNumber(value);
  final prefix = approximate ? '~' : '';
  if (unit.symbol.isEmpty) return '$prefix$n';
  if (unit.code == 'ratio') return '$prefix$n×';
  if (unit.code == 'percent') return '$prefix$n%';
  return '$prefix$n ${unit.symbol}';
}

/// Picks the most readable unit for a base (SI) value, e.g. 3.84e8 m → km.
///
/// Chooses the largest unit in which the value is at least 1, so 100 m
/// reads as "100 m" rather than "0.1 km".
Unit bestDisplayUnit(double si, Dimension dimension, {Unit? fallback}) {
  final ladder = displayLadders[dimension];
  if (ladder == null) return fallback ?? units.values.firstWhere((u) => u.dimension == dimension);
  if (si == 0) return fallback ?? units.values.firstWhere((u) => u.dimension == dimension && u.toSi == 1);
  var best = units[ladder.first]!;
  for (final code in ladder) {
    final u = units[code]!;
    if (si.abs() / u.toSi >= 1) best = u;
  }
  return best;
}

/// Formats a base (SI) value in its most readable unit.
String formatSi(double si, Dimension dimension, {Unit? fallback}) {
  final unit = bestDisplayUnit(si, dimension, fallback: fallback);
  return formatQuantity(unit.fromBase(si), unit);
}

String _sup(int n) => n.toString().split('').map((c) => _superscripts[c]!).join();

String _sig(double v, int significant) {
  if (v == 0) return '0';
  final digits = (math.log(v) / math.ln10).floor() + 1;
  final decimals = (significant - digits).clamp(0, 6);
  return v.toStringAsFixed(decimals);
}

String _trim(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

String _group(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}
