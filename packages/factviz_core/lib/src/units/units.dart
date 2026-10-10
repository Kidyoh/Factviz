/// Physical dimension of a unit. Two quantities can only be compared on one
/// template when they share a [Unit.compatibilityKey].
enum Dimension {
  length,
  mass,
  duration,
  speed,
  area,
  volume,
  money,
  count,
  ratio;

  /// Whether quantities of this dimension can be drawn as physical sizes.
  bool get isSpatial => this == length || this == area || this == volume;
}

/// A unit the facts layer is allowed to use.
class Unit {
  const Unit(this.code, this.dimension, this.toSi, this.symbol, this.name);

  /// Wire code used in JSON, e.g. `km`.
  final String code;
  final Dimension dimension;

  /// Multiplier converting a value in this unit to the dimension's base unit
  /// (m, kg, s, m/s, m², m³, one currency unit, 1).
  final double toSi;

  /// Short symbol for display, e.g. `km`, `m²`.
  final String symbol;
  final String name;

  /// Currencies share a dimension but cannot be compared without an
  /// exchange rate, so each currency is its own compatibility group.
  String get compatibilityKey =>
      dimension == Dimension.money ? 'money:$code' : dimension.name;

  bool isCompatibleWith(Unit other) => compatibilityKey == other.compatibilityKey;

  double toBase(double value) => value * toSi;
  double fromBase(double si) => si / toSi;

  @override
  String toString() => code;
}

const double _yearSeconds = 365.25 * 86400;

/// Every unit the facts layer may use, keyed by wire code.
const Map<String, Unit> units = {
  // Length (base: metre)
  'nm': Unit('nm', Dimension.length, 1e-9, 'nm', 'nanometres'),
  'um': Unit('um', Dimension.length, 1e-6, 'µm', 'micrometres'),
  'mm': Unit('mm', Dimension.length, 1e-3, 'mm', 'millimetres'),
  'cm': Unit('cm', Dimension.length, 1e-2, 'cm', 'centimetres'),
  'm': Unit('m', Dimension.length, 1, 'm', 'metres'),
  'km': Unit('km', Dimension.length, 1e3, 'km', 'kilometres'),
  'ft': Unit('ft', Dimension.length, 0.3048, 'ft', 'feet'),
  'mi': Unit('mi', Dimension.length, 1609.344, 'mi', 'miles'),
  'au': Unit('au', Dimension.length, 1.495978707e11, 'AU', 'astronomical units'),
  'ly': Unit('ly', Dimension.length, 9.4607304725808e15, 'ly', 'light-years'),
  'pc': Unit('pc', Dimension.length, 3.0856775814913673e16, 'pc', 'parsecs'),
  // Mass (base: kilogram)
  'mg': Unit('mg', Dimension.mass, 1e-6, 'mg', 'milligrams'),
  'g': Unit('g', Dimension.mass, 1e-3, 'g', 'grams'),
  'kg': Unit('kg', Dimension.mass, 1, 'kg', 'kilograms'),
  't': Unit('t', Dimension.mass, 1e3, 't', 'tonnes'),
  'lb': Unit('lb', Dimension.mass, 0.45359237, 'lb', 'pounds'),
  // Duration (base: second)
  's': Unit('s', Dimension.duration, 1, 's', 'seconds'),
  'min': Unit('min', Dimension.duration, 60, 'min', 'minutes'),
  'h': Unit('h', Dimension.duration, 3600, 'h', 'hours'),
  'day': Unit('day', Dimension.duration, 86400, 'days', 'days'),
  'yr': Unit('yr', Dimension.duration, _yearSeconds, 'years', 'years'),
  // Speed (base: metre per second)
  'm/s': Unit('m/s', Dimension.speed, 1, 'm/s', 'metres per second'),
  'km/h': Unit('km/h', Dimension.speed, 1 / 3.6, 'km/h', 'kilometres per hour'),
  'mph': Unit('mph', Dimension.speed, 0.44704, 'mph', 'miles per hour'),
  // Area (base: square metre)
  'm2': Unit('m2', Dimension.area, 1, 'm²', 'square metres'),
  'km2': Unit('km2', Dimension.area, 1e6, 'km²', 'square kilometres'),
  // Volume (base: cubic metre)
  'mL': Unit('mL', Dimension.volume, 1e-6, 'mL', 'millilitres'),
  'L': Unit('L', Dimension.volume, 1e-3, 'L', 'litres'),
  'm3': Unit('m3', Dimension.volume, 1, 'm³', 'cubic metres'),
  // Money (base: one unit of the currency)
  'USD': Unit('USD', Dimension.money, 1, 'USD', 'US dollars'),
  'EUR': Unit('EUR', Dimension.money, 1, 'EUR', 'euros'),
  // Dimensionless
  'count': Unit('count', Dimension.count, 1, '', 'count'),
  'ratio': Unit('ratio', Dimension.ratio, 1, '×', 'ratio'),
};

/// Units preferred when re-expressing a base value for display, smallest
/// first. Dimensions without a ladder are shown in their base unit.
const Map<Dimension, List<String>> displayLadders = {
  Dimension.length: ['nm', 'um', 'mm', 'cm', 'm', 'km', 'au', 'ly'],
  Dimension.mass: ['mg', 'g', 'kg', 't'],
  Dimension.duration: ['s', 'min', 'h', 'day', 'yr'],
  Dimension.speed: ['km/h'],
  Dimension.area: ['m2', 'km2'],
  Dimension.volume: ['mL', 'L', 'm3'],
};
