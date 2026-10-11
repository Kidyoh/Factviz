import 'package:factviz/data/library_repository.dart';
import 'package:factviz/templates/mock_data.dart';
import 'package:factviz/ui/visualization_panel.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_viz.dart';
import '../support/test_app.dart';

void main() {
  test('mock samples and the bundled library together cover every template', () async {
    final library = await LibraryRepository(rootBundle).load();
    final templates = {
      ...mockSamples.map((s) => s.visualization.props.template),
      ...library.entries.map((e) => e.template),
    };
    expect(templates, TemplateId.values.toSet());
  });

  test('every mock sample serialises to render JSON', () {
    for (final s in mockSamples) {
      final json = renderJson(s.visualization.props);
      expect(json['template'], s.visualization.props.template.wire, reason: s.name);
    }
  });

  for (final (label, size) in [('phone', const Size(390, 844)), ('small phone', const Size(320, 640))]) {
    for (final reduce in [false, true]) {
      group('$label${reduce ? ', reduced motion' : ''}', () {
        for (final sample in mockSamples) {
          testWidgets(sample.name, (tester) async {
            await pumpPhone(
              tester,
              SingleChildScrollView(child: VisualizationPanel(visualization: sample.visualization)),
              size: size,
              reduceMotion: reduce,
            );
            await advance(tester, const Duration(seconds: 2));
            expect(tester.takeException(), isNull);
            expect(find.text(sample.visualization.props.title), findsOneWidget);
            final props = sample.visualization.props;
            if (props is! NoneProps) {
              expect(find.text('viz:${props.template.wire}#0'), findsOneWidget);
            }
            for (final fact in sample.visualization.keyFacts) {
              expect(find.text('Source: ${fact.sourceNote}'), findsWidgets, reason: fact.id);
            }
          });
        }
      });
    }
  }

  testWidgets('replay key reaches the renderer', (tester) async {
    final viz = mockSamples.first.visualization;
    FakeViz.rendered.clear();
    await pumpPhone(tester, SingleChildScrollView(child: VisualizationPanel(visualization: viz, replayKey: 3)));
    expect(FakeViz.rendered.last, (viz.props.template.wire, 3));
    await advance(tester, const Duration(seconds: 1));
  });
}
