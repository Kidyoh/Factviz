part of 'plan.dart';

// Plans for the extended chart library. Several templates share one plan
// shape (items, pairs); each template has its own limits, enforced here, and
// its own rules about facts, enforced by PlanResolver.

/// A fact reference with a display name and optional picture.
class ItemRef {
  const ItemRef({required this.factId, required this.displayName, this.image});

  final String factId;
  final String displayName;
  final String? image;

  static ItemRef? _read(JsonReader r) {
    final factId = _factId(r, 'factId');
    final displayName = r.string('displayName', maxLength: 40);
    final image = _image(r);
    if (factId == null || displayName == null) return null;
    return ItemRef(factId: factId, displayName: displayName, image: image);
  }

  Map<String, Object?> toJson() => {'factId': factId, 'displayName': displayName, 'image': ?image};
}

/// Item-count limits per items template.
const Map<TemplateId, (int, int)> itemLimits = {
  TemplateId.donut: (2, 8),
  TemplateId.stackedBar: (2, 8),
  TemplateId.waffle: (1, 4),
  TemplateId.treemap: (3, 30),
  TemplateId.bubblePack: (3, 40),
  TemplateId.lollipop: (3, 25),
  TemplateId.numberLine: (2, 15),
};

/// donut, stacked_bar, waffle, treemap, bubble_pack, lollipop, number_line:
/// a list of quantities, optionally parts of a stated total.
final class ItemsPlan extends Plan {
  const ItemsPlan({
    required this.template,
    required super.title,
    super.caption,
    required this.items,
    this.totalFactId,
    this.scale = AxisScale.linear,
  });

  @override
  final TemplateId template;
  final List<ItemRef> items;

  /// donut / stacked_bar: the whole the parts belong to. Anything not
  /// covered by the parts is drawn as "Other".
  final String? totalFactId;

  /// number_line / lollipop: linear or log axis.
  final AxisScale scale;

  @override
  List<String> get factIds => [for (final i in items) i.factId, ?totalFactId];

  static ItemsPlan? _read(TemplateId template, JsonReader r, String? title, String? caption) {
    final (min, max) = itemLimits[template]!;
    final items = r.objects('items', ItemRef._read, minItems: min, maxItems: max);
    final total = _factId(r, 'totalFactId', optional: true);
    final scale = r.choice('scale', AxisScale.byWire, optional: true) ?? AxisScale.linear;
    if (title == null || items == null) return null;
    return ItemsPlan(template: template, title: title, caption: caption, items: items, totalFactId: total, scale: scale);
  }

  @override
  Map<String, Object?> propsToJson() => {
        'items': [for (final i in items) i.toJson()],
        'totalFactId': ?totalFactId,
        if (scale != AxisScale.linear) 'scale': scale.name,
      };
}

/// One row of a pairs template: two facts compared side by side.
class PairRef {
  const PairRef({required this.label, required this.aFactId, required this.bFactId});

  final String label;
  final String aFactId;
  final String bFactId;

  static PairRef? _read(JsonReader r) {
    final label = r.string('label', maxLength: 40);
    final a = _factId(r, 'aFactId');
    final b = _factId(r, 'bFactId');
    if (label == null || a == null || b == null) return null;
    return PairRef(label: label, aFactId: a, bFactId: b);
  }

  Map<String, Object?> toJson() => {'label': label, 'aFactId': aFactId, 'bFactId': bFactId};
}

const Map<TemplateId, (int, int)> pairLimits = {
  TemplateId.slope: (1, 10),
  TemplateId.rangeBars: (2, 12),
  TemplateId.versus: (2, 8),
  TemplateId.rateCounter: (1, 4),
};

/// slope (a = before, b = after), range_bars (a = low, b = high), versus
/// (a = left subject, b = right subject), rate_counter (a = count,
/// b = period).
final class PairsPlan extends Plan {
  const PairsPlan({
    required this.template,
    required super.title,
    super.caption,
    required this.rows,
    this.aName,
    this.bName,
    this.aImage,
    this.bImage,
  });

  @override
  final TemplateId template;
  final List<PairRef> rows;

  /// versus: the two subjects' names and optional pictures.
  final String? aName;
  final String? bName;
  final String? aImage;
  final String? bImage;

  @override
  List<String> get factIds => [for (final p in rows) ...[p.aFactId, p.bFactId]];

  static PairsPlan? _read(TemplateId template, JsonReader r, String? title, String? caption) {
    final (min, max) = pairLimits[template]!;
    final rows = r.objects('rows', PairRef._read, minItems: min, maxItems: max);
    final versus = template == TemplateId.versus;
    final aName = r.string('aName', optional: !versus, maxLength: 30);
    final bName = r.string('bName', optional: !versus, maxLength: 30);
    String? img(String key) {
      final v = r.string(key, optional: true, maxLength: 30);
      if (v != null && !imageCatalog.containsKey(v)) {
        r.issue('unknown image "$v"; allowed: ${imageCatalog.keys.join(', ')}', key: key);
        return null;
      }
      return v;
    }

    final aImage = img('aImage'), bImage = img('bImage');
    if (title == null || rows == null) return null;
    return PairsPlan(
      template: template,
      title: title,
      caption: caption,
      rows: rows,
      aName: aName,
      bName: bName,
      aImage: aImage,
      bImage: bImage,
    );
  }

  @override
  Map<String, Object?> propsToJson() => {
        'rows': [for (final p in rows) p.toJson()],
        'aName': ?aName,
        'bName': ?bName,
        'aImage': ?aImage,
        'bImage': ?bImage,
      };
}

/// pictogram: how many of one thing make up another ("13 buses = 1 whale").
final class PictogramPlan extends Plan {
  const PictogramPlan({
    required super.title,
    super.caption,
    required this.unitFactId,
    required this.totalFactId,
    required this.unitName,
    required this.totalName,
    this.image,
  });

  final String unitFactId;
  final String totalFactId;
  final String unitName;
  final String totalName;
  final String? image;

  @override
  TemplateId get template => TemplateId.pictogram;

  @override
  List<String> get factIds => [totalFactId, unitFactId];

  static PictogramPlan? _read(JsonReader r, String? title, String? caption) {
    final unit = _factId(r, 'unitFactId');
    final total = _factId(r, 'totalFactId');
    final unitName = r.string('unitName', maxLength: 30);
    final totalName = r.string('totalName', maxLength: 30);
    final image = _image(r);
    if (title == null || unit == null || total == null || unitName == null || totalName == null) return null;
    return PictogramPlan(
      title: title,
      caption: caption,
      unitFactId: unit,
      totalFactId: total,
      unitName: unitName,
      totalName: totalName,
      image: image,
    );
  }

  @override
  Map<String, Object?> propsToJson() => {
        'unitFactId': unitFactId,
        'totalFactId': totalFactId,
        'unitName': unitName,
        'totalName': totalName,
        'image': ?image,
      };
}

class SeriesRef {
  const SeriesRef({required this.displayName, required this.factIds});

  final String displayName;
  final List<String> factIds;

  static SeriesRef? _read(JsonReader r) {
    final name = r.string('displayName', maxLength: 30);
    final ids = _factIds(r, 'factIds', 3, 60);
    if (name == null || ids == null) return null;
    return SeriesRef(displayName: name, factIds: ids);
  }

  Map<String, Object?> toJson() => {'displayName': displayName, 'factIds': factIds};
}

/// line_series: quantities over time; each fact carries a year.
final class SeriesPlan extends Plan {
  const SeriesPlan({required super.title, super.caption, required this.series, this.scale = AxisScale.linear});

  final List<SeriesRef> series;
  final AxisScale scale;

  @override
  TemplateId get template => TemplateId.lineSeries;

  @override
  List<String> get factIds => [for (final s in series) ...s.factIds];

  static SeriesPlan? _read(JsonReader r, String? title, String? caption) {
    final series = r.objects('series', SeriesRef._read, minItems: 1, maxItems: 4);
    final scale = r.choice('scale', AxisScale.byWire, optional: true) ?? AxisScale.linear;
    if (title == null || series == null) return null;
    return SeriesPlan(title: title, caption: caption, series: series, scale: scale);
  }

  @override
  Map<String, Object?> propsToJson() =>
      {'series': [for (final s in series) s.toJson()], if (scale != AxisScale.linear) 'scale': scale.name};
}

/// cosmic_clock: a long history squeezed into one 24-hour day.
final class ClockPlan extends Plan {
  const ClockPlan({required super.title, super.caption, required this.eventFactIds});

  final List<String> eventFactIds;

  @override
  TemplateId get template => TemplateId.cosmicClock;

  @override
  List<String> get factIds => eventFactIds;

  static ClockPlan? _read(JsonReader r, String? title, String? caption) {
    final ids = _factIds(r, 'eventFactIds', 3, 15);
    if (title == null || ids == null) return null;
    return ClockPlan(title: title, caption: caption, eventFactIds: ids);
  }

  @override
  Map<String, Object?> propsToJson() => {'eventFactIds': eventFactIds};
}

class PointRef {
  const PointRef({required this.placeFactId, required this.displayName, this.valueFactId});

  final String placeFactId;
  final String displayName;
  final String? valueFactId;

  static PointRef? _read(JsonReader r) {
    final place = _factId(r, 'placeFactId');
    final name = r.string('displayName', maxLength: 40);
    final value = _factId(r, 'valueFactId', optional: true);
    if (place == null || name == null) return null;
    return PointRef(placeFactId: place, displayName: name, valueFactId: value);
  }

  Map<String, Object?> toJson() => {'placeFactId': placeFactId, 'displayName': displayName, 'valueFactId': ?valueFactId};
}

/// map_points: places on a world map, optionally sized by a value.
final class MapPlan extends Plan {
  const MapPlan({required super.title, super.caption, required this.points});

  final List<PointRef> points;

  @override
  TemplateId get template => TemplateId.mapPoints;

  @override
  List<String> get factIds => [for (final p in points) ...[p.placeFactId, ?p.valueFactId]];

  static MapPlan? _read(JsonReader r, String? title, String? caption) {
    final points = r.objects('points', PointRef._read, minItems: 1, maxItems: 30);
    if (title == null || points == null) return null;
    return MapPlan(title: title, caption: caption, points: points);
  }

  @override
  Map<String, Object?> propsToJson() => {'points': [for (final p in points) p.toJson()]};
}
