part of 'template_props.dart';

// Props for the extended chart library. Like the original five, every
// number here comes from a fact; the only derived values are arithmetic on
// facts (shares of a total, a remainder, a rate per second, a clock time).

/// One quantity in an items chart.
class PartItem {
  const PartItem({required this.displayName, required this.quantity, this.image, this.remainder = false});

  final String displayName;
  final ResolvedQuantity quantity;
  final ImageAsset? image;

  /// The "Other" slice: total minus the listed parts.
  final bool remainder;

  double get valueSi => quantity.valueSi;
}

/// donut, stacked_bar, waffle, treemap, bubble_pack, lollipop, number_line.
final class ItemsProps extends TemplateProps {
  const ItemsProps({
    required super.title,
    super.caption,
    required this.template,
    required this.dimension,
    required this.items,
    this.total,
    this.scale = AxisScale.linear,
  });

  @override
  final TemplateId template;
  final Dimension dimension;

  /// Part-to-whole charts keep the planner's order (plus a trailing
  /// remainder); treemap, bubble_pack and lollipop sort largest first;
  /// number_line sorts smallest first.
  final List<PartItem> items;

  /// The stated whole, for donut and stacked_bar.
  final ResolvedQuantity? total;
  final AxisScale scale;

  /// Sum used for shares: the stated total, else the sum of the parts.
  double get wholeSi => total?.valueSi ?? items.fold(0.0, (s, i) => s + i.valueSi);

  /// Fraction of the whole for item [i] (0..1). Waffle values are already
  /// percentages.
  double shareOf(PartItem i) {
    if (template == TemplateId.waffle) return i.quantity.value / 100;
    final w = wholeSi;
    return w <= 0 ? 0 : i.valueSi / w;
  }
}

/// One row of a pairs chart.
class PairRow {
  const PairRow({required this.label, required this.a, required this.b});

  final String label;
  final ResolvedQuantity a;
  final ResolvedQuantity b;
}

/// slope, range_bars, versus, rate_counter.
final class PairsProps extends TemplateProps {
  const PairsProps({
    required super.title,
    super.caption,
    required this.template,
    required this.rows,
    this.dimension,
    this.aName,
    this.bName,
    this.aImage,
    this.bImage,
  });

  @override
  final TemplateId template;
  final List<PairRow> rows;

  /// Shared dimension (slope, range_bars). Versus rows each have their own;
  /// rate_counter rows are count per duration.
  final Dimension? dimension;
  final String? aName;
  final String? bName;
  final ImageAsset? aImage;
  final ImageAsset? bImage;
}

/// pictogram: [count] copies of [unit] make up [total].
final class PictogramProps extends TemplateProps {
  const PictogramProps({
    required super.title,
    super.caption,
    required this.unit,
    required this.total,
    required this.unitName,
    required this.totalName,
    this.image,
  });

  final ResolvedQuantity unit;
  final ResolvedQuantity total;
  final String unitName;
  final String totalName;
  final ImageAsset? image;

  @override
  TemplateId get template => TemplateId.pictogram;

  double get count => total.valueSi / unit.valueSi;
}

class SeriesPoint {
  const SeriesPoint({required this.year, required this.quantity});

  final int year;
  final ResolvedQuantity quantity;
}

class Series {
  const Series({required this.displayName, required this.points});

  final String displayName;

  /// Sorted by year.
  final List<SeriesPoint> points;
}

/// line_series: values over time.
final class SeriesProps extends TemplateProps {
  const SeriesProps({
    required super.title,
    super.caption,
    required this.dimension,
    required this.unit,
    required this.series,
    required this.scale,
  });

  final Dimension dimension;

  /// Unit of the first point; display unit for money/count axes.
  final Unit unit;
  final List<Series> series;
  final AxisScale scale;

  @override
  TemplateId get template => TemplateId.lineSeries;
}

class ClockEvent {
  const ClockEvent({required this.event, required this.dayFraction});

  final TimelineEvent event;

  /// 0 = midnight at the oldest event, 1 = midnight now.
  final double dayFraction;

  /// "23:59:46" on the 24-hour clock.
  String get clockTime {
    final total = (dayFraction * 86400).floor().clamp(0, 86399);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(total ~/ 3600)}:${two(total % 3600 ~/ 60)}:${two(total % 60)}';
  }

  /// Real time represented by one clock second, used for captions.
  String secondsBeforeMidnight() {
    final s = ((1 - dayFraction) * 86400);
    if (s < 1) return 'less than a second before midnight';
    if (s < 60) return '${s.floor()} s before midnight';
    if (s < 3600) return '${(s / 60).floor()} min before midnight';
    return '${(s / 3600).floor()} h before midnight';
  }
}

/// cosmic_clock: a history compressed into one day.
final class ClockProps extends TemplateProps {
  const ClockProps({
    required super.title,
    super.caption,
    required this.referenceYear,
    required this.events,
  });

  final int referenceYear;

  /// Sorted oldest → newest.
  final List<ClockEvent> events;

  @override
  TemplateId get template => TemplateId.cosmicClock;

  /// Real years represented by one clock second.
  double get yearsPerSecond => (referenceYear - events.first.event.fractionalYear) / 86400;
}

class MapPoint {
  const MapPoint({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.placeSourceNote,
    this.value,
  });

  final String displayName;
  final double lat;
  final double lon;
  final String placeSourceNote;
  final ResolvedQuantity? value;
}

/// map_points: places on a world map.
final class MapProps extends TemplateProps {
  const MapProps({required super.title, super.caption, required this.points, this.dimension});

  final List<MapPoint> points;

  /// Shared dimension of the values, when points carry values.
  final Dimension? dimension;

  @override
  TemplateId get template => TemplateId.mapPoints;
}
