part of 'render_json.dart';

Map<String, Object?> _q(ResolvedQuantity q) => {
      'valueSi': q.valueSi,
      'display': q.displayValue,
      'source': q.sourceNote,
      'year': ?q.year,
    };

Map<String, Object?> _items(ItemsProps p) => {
      'scale': p.scale.name,
      'units': _units(p.dimension, p.items.first.quantity.unit),
      if (p.total != null) 'total': {'label': p.total!.label, ..._q(p.total!)},
      'items': [
        for (final i in p.items)
          {
            'name': i.displayName,
            ..._q(i.quantity),
            'share': p.shareOf(i),
            'shareDisplay': formatShare(p.shareOf(i)),
            if (i.remainder) 'remainder': true,
            if (i.image != null) 'image': i.image!.toRenderJson(),
          },
      ],
    };

Map<String, Object?> _pairs(PairsProps p) => {
      'aName': ?p.aName,
      'bName': ?p.bName,
      if (p.aImage != null) 'aImage': p.aImage!.toRenderJson(),
      if (p.bImage != null) 'bImage': p.bImage!.toRenderJson(),
      if (p.dimension != null && p.template != TemplateId.rateCounter)
        'units': _units(p.dimension!, p.rows.first.a.unit),
      'rows': [for (final r in p.rows) _pairRow(p.template, r)],
    };

Map<String, Object?> _pairRow(TemplateId t, PairRow r) {
  final row = <String, Object?>{'label': r.label, 'a': _q(r.a), 'b': _q(r.b)};
  switch (t) {
    case TemplateId.slope:
      row['change'] = changeText(r.a.valueSi, r.b.valueSi);
    case TemplateId.versus:
      final a = r.a.valueSi, b = r.b.valueSi;
      row['winner'] = a == b ? 'tie' : (a > b ? 'a' : 'b');
      final lo = math.min(a, b), hi = math.max(a, b);
      if (lo > 0 && hi / lo >= 1.05) row['ratio'] = formatRatio(hi / lo);
    case TemplateId.rateCounter:
      // In the amount's own unit per real second, so the ticking counter
      // reads in the fact's unit ("t", "USD", births).
      final perSecond = r.a.value / r.b.valueSi;
      row['perSecond'] = perSecond;
      row['suffix'] = r.a.unit.symbol;
      row['rateDisplay'] = _rateDisplay(perSecond, r.a.unit);
    default:
  }
  return row;
}

/// "≈ 4.3 every second", "≈ 260 every minute", "≈ 3 every day".
String _rateDisplay(double perSecond, Unit unit) {
  const periods = [(1.0, 'second'), (60.0, 'minute'), (3600.0, 'hour'), (86400.0, 'day'), (365.25 * 86400, 'year')];
  for (final (seconds, name) in periods) {
    final v = perSecond * seconds;
    if (v >= 1 || name == 'year') return '≈ ${formatQuantity(v, unit)} every $name';
  }
  return '';
}

Map<String, Object?> _pictogram(PictogramProps p) {
  final count = p.count;
  final countDisplay = count < 10 ? formatNumber(double.parse(count.toStringAsFixed(1))) : formatNumber(count.roundToDouble());
  // "1 blue whale", but "all your blood" and "one CD" stand on their own.
  final determined = RegExp(r'^(one|a|an|the|all|your|every|each)\b', caseSensitive: false).hasMatch(p.totalName);
  final totalPhrase = determined ? p.totalName : '1 ${p.totalName}';
  return {
    'unit': {'name': p.unitName, 'label': p.unit.label, ..._q(p.unit)},
    'total': {'name': p.totalName, 'label': p.total.label, ..._q(p.total)},
    'count': count,
    'countDisplay': countDisplay,
    'totalPhrase': totalPhrase,
    'headline': '$countDisplay ${p.unitName} = $totalPhrase',
    if (p.image != null) 'image': p.image!.toRenderJson(),
  };
}

Map<String, Object?> _series(SeriesProps p) => {
      'scale': p.scale.name,
      'units': _units(p.dimension, p.unit),
      'series': [
        for (final s in p.series)
          {
            'name': s.displayName,
            'points': [for (final pt in s.points) _q(pt.quantity)],
          },
      ],
    };

Map<String, Object?> _clock(ClockProps p) => {
      'referenceYear': p.referenceYear,
      'scaleNote': 'Each second on this clock is about ${_yearsText(p.yearsPerSecond)}.',
      'events': [
        for (final e in p.events)
          {
            'label': e.event.label,
            'date': e.event.displayDate,
            'dayFraction': e.dayFraction,
            'clock': e.clockTime,
            'before': e.secondsBeforeMidnight(),
            'description': ?e.event.description,
            'source': e.event.sourceNote,
          },
      ],
    };

String _yearsText(double years) {
  if (years >= 1) return '${formatNumber(years)} ${years == 1 ? 'year' : 'years'}';
  final days = years * 365.25;
  if (days >= 1) return '${formatNumber(days)} days';
  return '${formatNumber(days * 24)} hours';
}

Map<String, Object?> _map(MapProps p) => {
      if (p.dimension != null) 'units': _units(p.dimension!, p.points.first.value!.unit),
      'points': [
        for (final pt in p.points)
          {
            'name': pt.displayName,
            'lat': pt.lat,
            'lon': pt.lon,
            'source': pt.placeSourceNote,
            if (pt.value != null) 'value': _q(pt.value!),
          },
      ],
    };
