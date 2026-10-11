part of 'annotations.dart';

/// A share of a whole as a percentage: "45%", "4.5%", "<0.1%".
String formatShare(double fraction) {
  final pct = fraction * 100;
  if (pct <= 0) return '0%';
  if (pct < 0.1) return '<0.1%';
  if (pct < 10) return '${_trimZero(pct.toStringAsFixed(1))}%';
  return '${pct.round()}%';
}

/// Change from [a] to [b]: "+45%", "−30%", "3.2×". Null when [a] is 0.
String? changeText(double a, double b) {
  if (a <= 0) return null;
  final r = b / a;
  if (r >= 2) return formatRatio(r);
  final pct = (r - 1) * 100;
  if (pct.abs() < 0.5) return 'no change';
  final n = pct.abs() < 10 ? _trimZero(pct.abs().toStringAsFixed(1)) : '${pct.abs().round()}';
  return pct > 0 ? '+$n%' : '−$n%';
}

List<Annotation> _items(ItemsProps p) {
  final items = p.items;
  if (items.isEmpty) return const [];
  switch (p.template) {
    case TemplateId.donut || TemplateId.stackedBar || TemplateId.treemap || TemplateId.bubblePack:
      var li = -1;
      for (var i = 0; i < items.length; i++) {
        if (items[i].remainder) continue;
        if (li < 0 || items[i].valueSi > items[li].valueSi) li = i;
      }
      if (li < 0 || items.length < 2) return const [];
      return [Annotation('${items[li].displayName}: ${formatShare(p.shareOf(items[li]))} of the total', AnchorKind.item, li)];
    case TemplateId.waffle:
      final v = items.first.quantity.value;
      final text = v >= 5 && (v / 10).round() >= 1
          ? 'About ${(v / 10).round()} in every 10'
          : 'About ${math.max(1, v.round())} in every 100';
      return [Annotation(text, AnchorKind.item, 0)];
    case TemplateId.lollipop || TemplateId.numberLine:
      if (items.length < 2) return const [];
      final small = items.reduce((a, b) => a.valueSi <= b.valueSi ? a : b);
      final large = items.reduce((a, b) => a.valueSi >= b.valueSi ? a : b);
      final li = items.indexOf(large);
      if (small.valueSi <= 0 || identical(small, large)) return const [];
      final ratio = large.valueSi / small.valueSi;
      if (p.scale == AxisScale.log && ratio >= 1000) {
        final orders = (math.log(ratio) / math.ln10).round();
        return [Annotation('${small.displayName} to ${large.displayName}: $orders orders of magnitude', AnchorKind.item, li)];
      }
      // Buildings and people read as heights; everything else as lengths.
      final tall = items.any((i) => i.image != null && !i.image!.shapes.contains(ItemShape.bar));
      return [
        Annotation(compareText(p.dimension, large.displayName, small.displayName, ratio, vertical: tall, physical: large.image != null), AnchorKind.item, li),
      ];
    default:
      return const [];
  }
}

List<Annotation> _pairs(PairsProps p) {
  switch (p.template) {
    case TemplateId.slope:
      var best = -1;
      var bestScore = 0.0;
      for (var i = 0; i < p.rows.length; i++) {
        final a = p.rows[i].a.valueSi, b = p.rows[i].b.valueSi;
        if (a <= 0) continue;
        final score = (math.log(b <= 0 ? 1e-9 : b / a)).abs();
        if (best < 0 || score > bestScore) {
          best = i;
          bestScore = score;
        }
      }
      if (best < 0) return const [];
      final row = p.rows[best];
      final change = changeText(row.a.valueSi, row.b.valueSi);
      if (change == null || change == 'no change') return const [];
      final text = p.rows.length == 1 ? change : '${row.label}: $change';
      return [Annotation(text, AnchorKind.item, best)];
    case TemplateId.rangeBars:
      var best = -1;
      var bestRatio = 1.0;
      for (var i = 0; i < p.rows.length; i++) {
        final a = p.rows[i].a.valueSi, b = p.rows[i].b.valueSi;
        if (a <= 0) continue;
        if (b / a > bestRatio) {
          best = i;
          bestRatio = b / a;
        }
      }
      if (best < 0 || bestRatio < 1.5) return const [];
      return [Annotation('${p.rows[best].label}: high end is ${formatRatio(bestRatio)} the low end', AnchorKind.item, best)];
    default:
      return const [];
  }
}

List<Annotation> _series(SeriesProps p) {
  final s = p.series.first;
  if (s.points.length < 2) return const [];
  final first = s.points.first, last = s.points.last;
  final change = changeText(first.quantity.valueSi, last.quantity.valueSi);
  if (change == null || change == 'no change') return const [];
  final who = p.series.length > 1 ? '${s.displayName}: ' : '';
  return [Annotation('$who$change since ${_year(first.year)}', AnchorKind.item, 0, index2: s.points.length - 1)];
}

String _year(int y) => y < 0 ? '${-y} BCE' : '$y';

List<Annotation> _clock(ClockProps p) {
  final last = p.events.last;
  return [
    Annotation('${last.event.label}: ${last.clockTime}, ${last.secondsBeforeMidnight()}', AnchorKind.event, p.events.length - 1),
  ];
}
