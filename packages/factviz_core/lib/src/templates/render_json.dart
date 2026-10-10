import 'dart:math' as math;

import '../annotations/annotations.dart';
import '../units/units.dart';
import 'template_props.dart';

/// The JSON contract between the app and the D3 renderer.
///
/// Everything the renderer shows is precomputed here: display strings come
/// from the shared formatter, so the JS side never invents or reformats a
/// figure. The renderer only lays out, scales and animates.
Map<String, Object?> renderJson(TemplateProps props) => {
      'version': 1,
      'template': props.template.wire,
      'title': props.title,
      'caption': ?props.caption,
      'annotations': [for (final a in annotationsFor(props)) a.toJson()],
      ...switch (props) {
        ScaleZoomProps p => _scale(p),
        TimelineProps p => _timeline(p),
        ExponentialGrowthProps p => _growth(p),
        ComparisonBarsProps p => _bars(p),
        ProcessStepsProps p => _steps(p),
        NoneProps p => {'reason': p.reason},
      },
    };

/// Units the renderer may use for axis ticks, smallest first.
Map<String, Object?> _units(Dimension d, Unit fallback) {
  final ladder = displayLadders[d];
  return {
    'dimension': d.name,
    'ladder': [
      for (final code in ladder ?? [fallback.code]) {'symbol': units[code]!.symbol, 'toSi': units[code]!.toSi},
    ],
  };
}

double _linear(double si, Dimension d) => switch (d) {
      Dimension.area => math.sqrt(si),
      Dimension.volume => math.pow(si, 1 / 3).toDouble(),
      _ => si,
    };

Map<String, Object?> _scale(ScaleZoomProps p) => {
      'mode': p.mode.name,
      'units': _units(p.dimension.isSpatial ? Dimension.length : p.dimension, p.items.first.quantity.unit),
      'items': [
        for (final i in p.items)
          {
            'name': i.displayName,
            'shape': i.shape.name,
            'valueSi': i.valueSi,
            'linearSi': _linear(i.valueSi, p.dimension),
            'display': i.quantity.displayValue,
            'source': i.quantity.sourceNote,
            if (i.image != null) 'image': i.image!.toRenderJson(),
          },
      ],
    };

Map<String, Object?> _timeline(TimelineProps p) => {
      'axis': p.axis.wire,
      'referenceYear': p.referenceYear,
      'events': [
        for (final e in p.events)
          {
            'label': e.label,
            'date': e.displayDate,
            'year': e.fractionalYear,
            'yearsAgo': e.yearsAgo,
            'description': ?e.description,
            'source': e.sourceNote,
          },
      ],
    };

Map<String, Object?> _growth(ExponentialGrowthProps p) => {
      'stepLabel': p.stepLabel,
      'factor': p.factor,
      'steps': p.steps,
      'defaultScale': p.defaultScale.name,
      'units': _units(p.dimension, p.initial.unit),
      'initial': {'label': p.initial.label, 'display': p.initial.displayValue, 'valueSi': p.initial.valueSi},
      if (p.target != null)
        'target': {'label': p.target!.label, 'display': p.target!.displayValue, 'valueSi': p.target!.valueSi},
      'targetStep': ?p.targetStep,
      'series': [
        for (var s = 0; s <= p.steps; s++)
          {'step': s, 'valueSi': p.valueAtStepSi(s), 'display': p.formatValueSi(p.valueAtStepSi(s))},
      ],
    };

Map<String, Object?> _bars(ComparisonBarsProps p) => {
      'orientation': p.orientation.name,
      'units': _units(p.dimension, p.bars.first.quantity.unit),
      'bars': [
        for (final b in p.bars)
          {
            'name': b.displayName,
            'valueSi': b.valueSi,
            'display': b.quantity.displayValue,
            'source': b.quantity.sourceNote,
            if (b.image != null) 'image': b.image!.toRenderJson(),
          },
      ],
    };

Map<String, Object?> _steps(ProcessStepsProps p) => {
      'loop': p.loop,
      'autoplayMs': p.autoplay.inMilliseconds,
      'steps': [
        for (final s in p.steps) {'order': s.order, 'title': s.title, 'description': s.description, 'source': s.sourceNote},
      ],
    };
