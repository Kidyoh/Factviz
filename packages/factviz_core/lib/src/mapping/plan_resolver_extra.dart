part of 'plan_resolver.dart';

// Resolution rules for the extended chart library.

extension on _Resolution {
  ImageAsset? _img(String? key) => key == null ? null : imageCatalog[key];

  /// Resolves quantity references; returns null if any is missing.
  List<QuantityFact>? _quantities(List<String> ids, String Function(int) path) {
    final out = <QuantityFact>[];
    for (var i = 0; i < ids.length; i++) {
      final f = _fact<QuantityFact>(ids[i], path(i), 'quantity');
      if (f != null) out.add(f);
    }
    return out.length == ids.length ? out : null;
  }

  bool _logRangeOk(List<double> si, String path) {
    if (si.any((v) => v <= 0)) {
      _issue(path, 'a log scale needs every value to be greater than 0');
      return false;
    }
    final range = si.reduce(math.max) / si.reduce(math.min);
    if (range > PlanResolver.maxScaleRange) {
      _issue(path, 'range is too large to draw (${range.toStringAsExponential(1)}×)');
      return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // donut, stacked_bar, waffle, treemap, bubble_pack, lollipop, number_line

  ItemsProps? _items(ItemsPlan plan) {
    final t = plan.template;
    final facts = _quantities([for (final i in plan.items) i.factId], (i) => 'items[$i].factId');
    final total = plan.totalFactId == null ? null : _fact<QuantityFact>(plan.totalFactId!, 'totalFactId', 'quantity');
    if (facts == null || (plan.totalFactId != null && total == null)) return null;

    final unit = _sameDimension([
      for (var i = 0; i < facts.length; i++) (facts[i], 'items[$i].factId'),
      if (total != null) (total, 'totalFactId'),
    ], 'items');
    if (unit == null) return null;
    final dim = unit.dimension;

    var ok = true;
    final partToWhole = t == TemplateId.donut || t == TemplateId.stackedBar;
    if (total != null && !partToWhole) {
      _issue('totalFactId', 'only donut and stacked_bar take a total');
      ok = false;
    }
    if (plan.scale == AxisScale.log && t != TemplateId.numberLine && t != TemplateId.lollipop) {
      _issue('scale', 'only number_line and lollipop can use a log scale');
      ok = false;
    }
    if (t == TemplateId.waffle && unit.code != 'percent') {
      _issue('items', 'waffle needs percent facts (got ${unit.code})');
      ok = false;
    }
    if (partToWhole && dim == Dimension.ratio) {
      _issue('items', '${t.wire} needs parts of a whole, not ratios');
      ok = false;
    }
    final mustBePositive = t == TemplateId.treemap || t == TemplateId.bubblePack;
    for (var i = 0; i < facts.length; i++) {
      if (mustBePositive && facts[i].value <= 0) {
        _issue('items[$i].factId', 'fact "${facts[i].id}" must be greater than 0 to have an area');
        ok = false;
      }
    }
    if (facts.every((f) => f.value <= 0)) {
      _issue('items', 'at least one value must be greater than 0');
      ok = false;
    }
    if (plan.scale == AxisScale.log && !_logRangeOk([for (final f in facts) f.valueSi], 'items')) ok = false;
    if (!ok) return null;

    final items = <PartItem>[
      for (var i = 0; i < facts.length; i++)
        PartItem(displayName: plan.items[i].displayName, quantity: _quantity(facts[i]), image: _img(plan.items[i].image)),
    ];

    ResolvedQuantity? whole = total == null ? null : _quantity(total);
    if (partToWhole) {
      final sumSi = items.fold(0.0, (s, i) => s + i.valueSi);
      // Percent parts without a stated total are parts of 100%.
      final wholeSi = whole?.valueSi ?? (unit.code == 'percent' ? 100.0 : null);
      if (wholeSi != null) {
        if (sumSi > wholeSi * 1.005) {
          _issue(total == null ? 'items' : 'totalFactId',
              'the parts add up to more than the whole (${formatSi(sumSi, dim, fallback: unit)} > ${formatSi(wholeSi, dim, fallback: unit)})');
          return null;
        }
        final rest = wholeSi - sumSi;
        if (rest > wholeSi * 0.005) {
          final restUnit = total?.unit ?? unit;
          items.add(PartItem(
            displayName: 'Other',
            remainder: true,
            quantity: ResolvedQuantity(
              factId: '${total?.id ?? 'percent'}_other',
              label: 'Everything else',
              value: restUnit.fromBase(rest),
              unit: restUnit,
              approximate: facts.any((f) => f.approximate) || (total?.approximate ?? false),
              sourceNote: total == null ? '100% minus the parts listed' : 'Total minus the parts listed',
            ),
          ));
        }
      }
    }

    switch (t) {
      case TemplateId.treemap || TemplateId.bubblePack || TemplateId.lollipop:
        items.sort((a, b) => b.valueSi.compareTo(a.valueSi));
      case TemplateId.numberLine:
        items.sort((a, b) => a.valueSi.compareTo(b.valueSi));
      default:
    }
    return ItemsProps(
      title: plan.title,
      caption: plan.caption,
      template: t,
      dimension: dim,
      items: List.unmodifiable(items),
      total: whole,
      scale: plan.scale,
    );
  }

  // -------------------------------------------------------------------------
  // slope, range_bars, versus, rate_counter

  PairsProps? _pairs(PairsPlan plan) {
    final t = plan.template;
    final rows = <PairRow>[];
    final all = <(QuantityFact, String)>[];
    var ok = true;
    for (var i = 0; i < plan.rows.length; i++) {
      final ref = plan.rows[i];
      final a = _fact<QuantityFact>(ref.aFactId, 'rows[$i].aFactId', 'quantity');
      final b = _fact<QuantityFact>(ref.bFactId, 'rows[$i].bFactId', 'quantity');
      if (a == null || b == null) {
        ok = false;
        continue;
      }
      switch (t) {
        case TemplateId.slope:
          if (a.year != null && b.year != null && a.year! > b.year!) {
            _issue('rows[$i]', 'aFactId is the earlier value: year ${a.year} is after ${b.year}');
            ok = false;
          }
          all.addAll([(a, 'rows[$i].aFactId'), (b, 'rows[$i].bFactId')]);
        case TemplateId.rangeBars:
          if (a.unit.isCompatibleWith(b.unit) && a.valueSi > b.valueSi) {
            _issue('rows[$i]', 'aFactId is the low end and must not exceed bFactId');
            ok = false;
          }
          all.addAll([(a, 'rows[$i].aFactId'), (b, 'rows[$i].bFactId')]);
        case TemplateId.versus:
          if (!a.unit.isCompatibleWith(b.unit)) {
            _issue('rows[$i]', 'both sides of a row must share a dimension '
                '(${a.unit.compatibilityKey} vs ${b.unit.compatibilityKey})');
            ok = false;
          } else if (a.value <= 0 && b.value <= 0) {
            _issue('rows[$i]', 'at least one side must be greater than 0');
            ok = false;
          }
        case TemplateId.rateCounter:
          const notCountable = {Dimension.duration, Dimension.ratio, Dimension.percent, Dimension.speed};
          if (notCountable.contains(a.unit.dimension)) {
            _issue('rows[$i].aFactId', 'must be an amount (count, money, mass, volume…), got ${a.unit.dimension.name}');
            ok = false;
          }
          if (b.unit.dimension != Dimension.duration || b.value <= 0) {
            _issue('rows[$i].bFactId', 'must be a duration greater than 0, e.g. 1 yr');
            ok = false;
          }
        default:
      }
      rows.add(PairRow(label: ref.label, a: _quantity(a), b: _quantity(b)));
    }
    if (!ok) return null;
    Dimension? dim;
    if (t == TemplateId.slope || t == TemplateId.rangeBars) {
      final unit = _sameDimension(all, 'rows');
      if (unit == null) return null;
      dim = unit.dimension;
    }
    if (t == TemplateId.rateCounter) dim = Dimension.duration;
    return PairsProps(
      title: plan.title,
      caption: plan.caption,
      template: t,
      rows: List.unmodifiable(rows),
      dimension: dim,
      aName: plan.aName,
      bName: plan.bName,
      aImage: _img(plan.aImage),
      bImage: _img(plan.bImage),
    );
  }

  // -------------------------------------------------------------------------
  // pictogram

  PictogramProps? _pictogram(PictogramPlan plan) {
    final unit = _fact<QuantityFact>(plan.unitFactId, 'unitFactId', 'quantity');
    final total = _fact<QuantityFact>(plan.totalFactId, 'totalFactId', 'quantity');
    if (unit == null || total == null) return null;
    if (_sameDimension([(unit, 'unitFactId'), (total, 'totalFactId')], 'totalFactId') == null) return null;
    if (unit.value <= 0) {
      _issue('unitFactId', 'fact "${unit.id}" must be greater than 0');
      return null;
    }
    final count = total.valueSi / unit.valueSi;
    if (count < 1) {
      _issue('totalFactId', 'the total is smaller than one unit (${count.toStringAsFixed(2)}); swap unitFactId and totalFactId');
      return null;
    }
    if (count > PlanResolver.maxPictogramCount) {
      _issue('totalFactId', 'too many units to draw (${formatNumber(count)}); use number_line or scale_zoom');
      return null;
    }
    return PictogramProps(
      title: plan.title,
      caption: plan.caption,
      unit: _quantity(unit),
      total: _quantity(total),
      unitName: plan.unitName,
      totalName: plan.totalName,
      image: _img(plan.image),
    );
  }

  // -------------------------------------------------------------------------
  // line_series

  SeriesProps? _series(SeriesPlan plan) {
    final all = <(QuantityFact, String)>[];
    final series = <Series>[];
    var ok = true;
    for (var s = 0; s < plan.series.length; s++) {
      final ref = plan.series[s];
      final facts = _quantities(ref.factIds, (i) => 'series[$s].factIds[$i]');
      if (facts == null) {
        ok = false;
        continue;
      }
      final years = <int>{};
      final points = <SeriesPoint>[];
      for (var i = 0; i < facts.length; i++) {
        final f = facts[i];
        final path = 'series[$s].factIds[$i]';
        all.add((f, path));
        if (f.year == null) {
          _issue(path, 'fact "${f.id}" needs a year to be placed on a time axis');
          ok = false;
        } else if (!years.add(f.year!)) {
          _issue(path, 'year ${f.year} appears twice in this series');
          ok = false;
        } else {
          points.add(SeriesPoint(year: f.year!, quantity: _quantity(f)));
        }
      }
      points.sort((a, b) => a.year.compareTo(b.year));
      series.add(Series(displayName: ref.displayName, points: List.unmodifiable(points)));
    }
    if (!ok) return null;
    final unit = _sameDimension(all, 'series');
    if (unit == null) return null;
    if (plan.scale == AxisScale.log && !_logRangeOk([for (final f in all) f.$1.valueSi], 'series')) return null;
    return SeriesProps(
      title: plan.title,
      caption: plan.caption,
      dimension: unit.dimension,
      unit: unit,
      series: List.unmodifiable(series),
      scale: plan.scale,
    );
  }

  // -------------------------------------------------------------------------
  // cosmic_clock

  ClockProps? _clock(ClockPlan plan) {
    final timeline = _timeline(TimelinePlan(
      title: plan.title,
      caption: plan.caption,
      eventFactIds: plan.eventFactIds,
      axis: TimeAxis.linear,
    ));
    if (timeline == null) return null;
    final events = timeline.events;
    final start = events.first.fractionalYear;
    final span = referenceYear - start;
    if (events.last.fractionalYear > referenceYear) {
      _issue('eventFactIds', 'cosmic_clock events must be in the past');
      return null;
    }
    if (span < 100) {
      _issue('eventFactIds', 'cosmic_clock needs a long history (at least a century); use timeline instead');
      return null;
    }
    return ClockProps(
      title: plan.title,
      caption: plan.caption,
      referenceYear: referenceYear,
      events: List.unmodifiable([
        for (final e in events) ClockEvent(event: e, dayFraction: (e.fractionalYear - start) / span),
      ]),
    );
  }

  // -------------------------------------------------------------------------
  // map_points

  MapProps? _map(MapPlan plan) {
    final points = <MapPoint>[];
    final values = <(QuantityFact, String)>[];
    var ok = true;
    final withValue = plan.points.where((p) => p.valueFactId != null).length;
    if (withValue != 0 && withValue != plan.points.length) {
      _issue('points', 'give every point a valueFactId, or none');
      ok = false;
    }
    for (var i = 0; i < plan.points.length; i++) {
      final ref = plan.points[i];
      final place = _fact<PlaceFact>(ref.placeFactId, 'points[$i].placeFactId', 'place');
      final value = ref.valueFactId == null ? null : _fact<QuantityFact>(ref.valueFactId!, 'points[$i].valueFactId', 'quantity');
      if (place == null || (ref.valueFactId != null && value == null)) {
        ok = false;
        continue;
      }
      if (value != null) values.add((value, 'points[$i].valueFactId'));
      points.add(MapPoint(
        displayName: ref.displayName,
        lat: place.lat,
        lon: place.lon,
        placeSourceNote: place.sourceNote,
        value: value == null ? null : _quantity(value),
      ));
    }
    if (!ok) return null;
    Dimension? dim;
    if (values.isNotEmpty) {
      final unit = _sameDimension(values, 'points');
      if (unit == null) return null;
      if (values.every((v) => v.$1.value <= 0)) {
        _issue('points', 'at least one value must be greater than 0');
        return null;
      }
      dim = unit.dimension;
    }
    return MapProps(title: plan.title, caption: plan.caption, points: List.unmodifiable(points), dimension: dim);
  }
}
