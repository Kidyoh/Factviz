import 'package:factviz/main.dart';
import 'package:factviz/state/share.dart';
import 'package:factviz/state/visualize_controller.dart';
import 'package:factviz/templates/common/motion.dart';
import 'package:factviz/ui/example_prompts.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_server.dart';
import 'support/fake_viz.dart';
import 'support/test_app.dart';

Finder _viz(String template) => find.textContaining('viz:$template#');

void main() {
  setUp(() {
    VisualizeController.renderHold = const Duration(milliseconds: 300);
    ambientMotionEnabled = false;
  });

  late List<String> shared;

  Future<void> pumpApp(WidgetTester tester, FakeServer server, {String initialLocation = '/'}) async {
    shared = [];
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(server.client()),
        fakeVizOverride,
        shareTextProvider.overrideWithValue((text, {subject}) async => shared.add(text)),
      ],
      child: FactvizApp(initialLocation: initialLocation),
    ));
    await tester.pump();
  }

  Future<void> ask(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  testWidgets('home shows one search box and six example prompts', (tester) async {
    await pumpApp(tester, FakeServer());
    expect(find.text('What would you like to see?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ExampleRow), findsNWidgets(6));
    expect(examplePrompts, hasLength(6));
    await advance(tester, const Duration(seconds: 1));
  });

  testWidgets('shows each loading stage, then the visualization', (tester) async {
    final f = fixture('exponential_paper_fold');
    final server = FakeServer(facts: f.facts, plan: f.plan, latency: const Duration(milliseconds: 500));
    await pumpApp(tester, server);

    await tester.tap(find.text('Fold a paper 42 times to reach the Moon'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Finding facts'), findsWidgets);
    expect(find.bySemanticsLabel('Finding facts…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.bySemanticsLabel('Choosing visualization…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.bySemanticsLabel('Rendering…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('Folding paper to the Moon'), findsWidgets);
    expect(_viz('exponential_growth'), findsOneWidget);
    expect(find.text('THE NUMBERS'), findsOneWidget);
    expect(find.text('Source: NASA mean Earth–Moon distance'), findsOneWidget);
    expect(server.calls, ['/api/facts', '/api/plan']);
    await advance(tester, const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  });

  group('five fixed queries', () {
    for (final f in loadQueryFixtures()) {
      testWidgets('${f.query} → ${f.expectedTemplate}', (tester) async {
        final server = FakeServer(facts: f.facts, plan: f.plan, latency: const Duration(milliseconds: 10));
        await pumpApp(tester, server);
        await ask(tester, f.query);
        await advance(tester, const Duration(milliseconds: 600), steps: 12);
        expect(_viz(f.expectedTemplate), findsOneWidget);
        expect(find.text(f.plan['title'] as String), findsWidgets);
        await advance(tester, const Duration(seconds: 12));
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a failed visualization shows the friendly fallback; rephrase keeps the text', (tester) async {
    final server = FakeServer(facts: FakeServer.error(422, 'unvisualizable'), latency: Duration.zero);
    await pumpApp(tester, server);
    await ask(tester, 'What is the meaning of life?');
    await advance(tester, const Duration(milliseconds: 100), steps: 4);
    expect(find.text("Couldn't visualize this one, try rephrasing."), findsOneWidget);

    await tester.tap(find.text('Rephrase'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to see?'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'What is the meaning of life?'), findsOneWidget);
  });

  testWidgets('network errors can be retried', (tester) async {
    final f = fixture('comparison_whale_bus');
    final server = FakeServer(facts: http.ClientException('offline'), plan: f.plan, latency: Duration.zero);
    await pumpApp(tester, server);
    await ask(tester, f.query);
    await advance(tester, const Duration(milliseconds: 100), steps: 4);
    expect(find.textContaining("Can't reach the server"), findsOneWidget);

    server.facts = f.facts;
    await tester.tap(find.text('Try again'));
    await advance(tester, const Duration(milliseconds: 600), steps: 12);
    expect(_viz('comparison_bars'), findsOneWidget);
  });

  testWidgets('invalid data from the network never reaches a template', (tester) async {
    final f = fixture('scale_zoom_planets');
    final badPlan = Map<String, dynamic>.of(f.plan)..['items'] = [
          {'factId': 'mercury_diameter', 'displayName': 'Mercury'},
          {'factId': 'made_up', 'displayName': 'Planet X'},
        ];
    await pumpApp(tester, FakeServer(facts: f.facts, plan: badPlan, latency: Duration.zero));
    await ask(tester, f.query);
    await advance(tester, const Duration(milliseconds: 600), steps: 12);
    expect(_viz('scale_zoom'), findsNothing);
    expect(find.text("Couldn't visualize this one, try rephrasing."), findsOneWidget);
  });

  testWidgets('rate limiting shows a specific message', (tester) async {
    await pumpApp(tester, FakeServer(facts: FakeServer.error(429, 'rate_limited'), latency: Duration.zero));
    await ask(tester, 'How far is the Moon?');
    await advance(tester, const Duration(milliseconds: 100), steps: 4);
    expect(find.textContaining('a bit fast'), findsOneWidget);
  });

  testWidgets('low confidence results show a warning badge', (tester) async {
    final f = fixture('comparison_whale_bus');
    final facts = Map<String, dynamic>.of(f.facts)
      ..['confidence'] = 'low'
      ..['confidenceNote'] = 'Sources disagree on typical bus weights.';
    await pumpApp(tester, FakeServer(facts: facts, plan: f.plan, latency: Duration.zero));
    await ask(tester, f.query);
    await advance(tester, const Duration(milliseconds: 600), steps: 12);
    expect(find.text('LOW CONFIDENCE'), findsOneWidget);
    expect(find.textContaining('Sources disagree on typical bus weights.'), findsOneWidget);
  });

  testWidgets('share produces a link that re-renders with no API calls', (tester) async {
    final f = fixture('timeline_spaceflight');
    final server = FakeServer(facts: f.facts, plan: f.plan, latency: Duration.zero);
    await pumpApp(tester, server);
    await ask(tester, f.query);
    await advance(tester, const Duration(milliseconds: 600), steps: 12);
    await tester.tap(find.byTooltip('Share'));
    await tester.pump();

    expect(shared, hasLength(1));
    final link = Uri.parse(shared.single.split('\n').last);
    expect(link.scheme, 'factviz');
    expect(link.host, 'app');

    final fresh = FakeServer();
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, fresh, initialLocation: link.toString());
    await advance(tester, const Duration(seconds: 1), steps: 4);
    expect(find.text('Shared visualization'), findsOneWidget);
    expect(_viz('timeline'), findsOneWidget);
    expect(find.text('Milestones of human spaceflight'), findsWidgets);
    expect(fresh.calls, isEmpty);
  });

  testWidgets('a damaged share link shows an error without retry', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, initialLocation: 'factviz://app/v/garbage');
    await tester.pump();
    expect(find.textContaining('share link is damaged'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.text('Rephrase'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to see?'), findsOneWidget);
    expect(server.calls, isEmpty);
  });

  testWidgets('replay restarts the chart', (tester) async {
    final f = fixture('exponential_paper_fold');
    await pumpApp(tester, FakeServer(facts: f.facts, plan: f.plan, latency: Duration.zero));
    await ask(tester, f.query);
    await advance(tester, const Duration(milliseconds: 800), steps: 12);
    expect(find.text('viz:exponential_growth#0'), findsOneWidget);
    await tester.tap(find.byTooltip('Replay'));
    await tester.pump();
    expect(find.text('viz:exponential_growth#1'), findsOneWidget);
  });

  test('share message carries the title and a factviz link', () {
    final f = fixture('process_water_cycle');
    final viz = Visualization.build(
      FactsResult.fromJson(f.facts).valueOrThrow,
      Plan.fromJson(f.plan).valueOrThrow,
    ).valueOrThrow;
    final message = shareMessage(viz);
    expect(message, startsWith('How the water cycle works\nfactviz://app/v/'));
  });
}
