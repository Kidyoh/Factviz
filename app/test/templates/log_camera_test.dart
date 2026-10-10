import 'dart:math' as math;

import 'package:factviz/templates/mock_data.dart';
import 'package:factviz/templates/scale_zoom/log_camera.dart';
import 'package:factviz/templates/timeline/timeline_layout.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<T> _all<T extends TemplateProps>() => mockSamples.map((s) => s.visualization.props).whereType<T>().toList();

void main() {
  group('LogCamera', () {
    test('stops are non-decreasing and every item fits at its stop', () {
      for (final props in _all<ScaleZoomProps>()) {
        final placed = layoutScaleItems(props);
        final camera = LogCamera.forItems(placed, props.mode, const Size(350, 300));
        for (var i = 1; i < camera.length; i++) {
          expect(camera.stops[i], greaterThanOrEqualTo(camera.stops[i - 1]), reason: props.title);
        }
        for (var i = 0; i < camera.length; i++) {
          expect(camera.stops[i], greaterThanOrEqualTo(placed[i].right), reason: '${props.title} item $i');
        }
      }
    });

    test('interpolates in log space between stops', () {
      final camera = LogCamera([1, 1e6]);
      expect(camera.widthAt(0), closeTo(1, 1e-9));
      expect(camera.widthAt(1), closeTo(1e6, 1e-3));
      expect(math.log(camera.widthAt(0.5)) / math.ln10, closeTo(3, 0.15));
      expect(camera.widthAt(-3), closeTo(1, 1e-9));
      expect(camera.widthAt(9), closeTo(1e6, 1e-3));
    });

    test('handles 17 orders of magnitude', () {
      final props = _all<ScaleZoomProps>().firstWhere((p) => p.log10Range > 15);
      final camera = LogCamera.forItems(layoutScaleItems(props), props.mode, const Size(350, 300));
      expect(camera.stops.every((s) => s.isFinite && s > 0), isTrue);
    });

    test('niceNumber rounds to 1, 2 or 5 × 10ⁿ', () {
      expect(niceNumber(0.9), 1);
      expect(niceNumber(2.7), 2);
      expect(niceNumber(4200), 5000);
      expect(niceNumber(8e10), 1e11);
    });

    test('areas and volumes are drawn by linear size', () {
      expect(linearSize(100, Dimension.area), 10);
      expect(linearSize(1000, Dimension.volume), closeTo(10, 1e-9));
      expect(linearSize(7, Dimension.length), 7);
    });
  });

  group('TimelineLayout', () {
    test('cards never overlap within a lane', () {
      for (final props in _all<TimelineProps>()) {
        for (final width in [320.0, 390.0, 800.0]) {
          final layout = TimelineLayout.compute(props, viewportWidth: width);
          final byLane = <int, List<double>>{};
          for (var i = 0; i < layout.lanes.length; i++) {
            byLane.putIfAbsent(layout.lanes[i], () => []).add(layout.cardLefts[i]);
          }
          for (final lefts in byLane.values) {
            for (var i = 1; i < lefts.length; i++) {
              expect(lefts[i] - lefts[i - 1], greaterThanOrEqualTo(136), reason: '${props.title} @ $width');
            }
          }
          expect(layout.levels, lessThanOrEqualTo(2));
          expect(layout.width, greaterThanOrEqualTo(width));
        }
      }
    });

    test('produces readable ticks for linear and log axes', () {
      for (final props in _all<TimelineProps>()) {
        final layout = TimelineLayout.compute(props, viewportWidth: 390);
        final ticks = timelineTicks(props, layout.width);
        expect(ticks, isNotEmpty, reason: props.title);
        for (var i = 1; i < ticks.length; i++) {
          expect((ticks[i].x - ticks[i - 1].x).abs(), greaterThanOrEqualTo(84 - 1e-6), reason: props.title);
        }
      }
    });
  });
}
