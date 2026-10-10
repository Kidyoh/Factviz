import 'package:factviz/templates/mock_data.dart';
import 'package:factviz/templates/template_view.dart';
import 'package:factviz/ui/visualization_panel.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  test('mock samples cover every template', () {
    final templates = mockSamples.map((s) => s.visualization.props.template).toSet();
    expect(templates, TemplateId.values.toSet());
  });

  for (final (label, size) in [('phone', const Size(390, 844)), ('small phone', const Size(320, 640))]) {
    for (final reduce in [false, true]) {
      group('$label${reduce ? ', reduced motion' : ''}', () {
        for (final sample in mockSamples) {
          testWidgets(sample.name, (tester) async {
            await pumpPhone(
              tester,
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: VisualizationPanel(visualization: sample.visualization),
              ),
              size: size,
              reduceMotion: reduce,
            );
            await advance(tester, const Duration(seconds: 12));
            expect(tester.takeException(), isNull);
            expect(find.text(sample.visualization.props.title), findsOneWidget);
            // Every source note is shown under Key numbers.
            for (final fact in sample.visualization.keyFacts) {
              expect(find.text(fact.sourceNote), findsWidgets, reason: fact.id);
            }
          });
        }
      });
    }
  }

  testWidgets('every template renders standalone', (tester) async {
    for (final sample in mockSamples) {
      await pumpPhone(tester, TemplateView(props: sample.visualization.props));
      await advance(tester, const Duration(seconds: 3), steps: 6);
      expect(tester.takeException(), isNull, reason: sample.name);
    }
  });
}
