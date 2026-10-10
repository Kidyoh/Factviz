import 'package:factviz/templates/exponential_growth/exponential_growth_view.dart';
import 'package:factviz/templates/mock_data.dart';
import 'package:factviz/templates/process_steps/process_steps_view.dart';
import 'package:factviz/templates/template_view.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

T _props<T extends TemplateProps>() =>
    mockSamples.map((s) => s.visualization.props).whereType<T>().first;

void main() {
  group('exponential_growth', () {
    testWidgets('counts up to the final step and announces the target', (tester) async {
      final props = _props<ExponentialGrowthProps>();
      await pumpPhone(tester, ExponentialGrowthView(props: props));
      expect(find.text('Fold 0 of 42'), findsOneWidget);
      await advance(tester, const Duration(seconds: 11));
      expect(find.text('Fold 42 of 42'), findsOneWidget);
      expect(find.text('Reaches Average Earth–Moon distance at fold 42'), findsOneWidget);
      expect(find.text(props.formatValueSi(props.finalValueSi)), findsOneWidget);
    });

    testWidgets('reduced motion starts at the end', (tester) async {
      await pumpPhone(tester, ExponentialGrowthView(props: _props<ExponentialGrowthProps>()), reduceMotion: true);
      await tester.pump();
      expect(find.text('Fold 42 of 42'), findsOneWidget);
    });

    testWidgets('step controls move one step at a time', (tester) async {
      await pumpPhone(tester, ExponentialGrowthView(props: _props<ExponentialGrowthProps>()), reduceMotion: true);
      await tester.pump();
      await tester.tap(find.byTooltip('Previous step'));
      await tester.pump();
      expect(find.text('Fold 41 of 42'), findsOneWidget);
      await tester.tap(find.byTooltip('Next step'));
      await tester.pump();
      expect(find.text('Fold 42 of 42'), findsOneWidget);
    });

    testWidgets('linear/log toggle switches scale', (tester) async {
      await pumpPhone(tester, ExponentialGrowthView(props: _props<ExponentialGrowthProps>()), reduceMotion: true);
      await tester.tap(find.text('Log'));
      await tester.pump();
      final button = tester.widget<SegmentedButton<AxisScale>>(find.byType(SegmentedButton<AxisScale>));
      expect(button.selected, {AxisScale.log});
    });
  });

  group('process_steps', () {
    testWidgets('auto-plays through steps and loops', (tester) async {
      final props = _props<ProcessStepsProps>();
      await pumpPhone(tester, ProcessStepsView(props: props));
      expect(find.text('Step 1 of 4'), findsOneWidget);
      await advance(tester, props.autoplay + const Duration(milliseconds: 400));
      expect(find.text('Step 2 of 4'), findsOneWidget);
      await advance(tester, props.autoplay * 3 + const Duration(milliseconds: 400), steps: 60);
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });

    testWidgets('pause stops autoplay; step buttons still work', (tester) async {
      final props = _props<ProcessStepsProps>();
      await pumpPhone(tester, ProcessStepsView(props: props));
      await tester.tap(find.byTooltip('Pause'));
      await advance(tester, props.autoplay * 2);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      await tester.tap(find.byTooltip('Next step'));
      await advance(tester, const Duration(milliseconds: 500), steps: 5);
      expect(find.text('Step 2 of 4'), findsOneWidget);
    });

    testWidgets('reduced motion does not autoplay', (tester) async {
      final props = _props<ProcessStepsProps>();
      await pumpPhone(tester, ProcessStepsView(props: props), reduceMotion: true);
      await advance(tester, props.autoplay * 2);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
    });
  });

  testWidgets('changing replayKey restarts the animation', (tester) async {
    final props = _props<ExponentialGrowthProps>();
    Widget build(int key) => TemplateView(props: props, replayKey: key);
    await pumpPhone(tester, build(0));
    await advance(tester, const Duration(seconds: 11));
    expect(find.text('Fold 42 of 42'), findsOneWidget);
    await pumpPhone(tester, build(1));
    await tester.pump();
    expect(find.text('Fold 0 of 42'), findsOneWidget);
  });
}
