import 'dart:convert';

import 'package:factviz/data/api_key_store.dart';
import 'package:factviz/data/library_repository.dart';
import 'package:factviz/main.dart';
import 'package:factviz/state/library.dart';
import 'package:factviz/state/visualize_controller.dart';
import 'package:factviz/templates/common/motion.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';
import 'support/fake_viz.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<LibraryCategory> library;
  setUpAll(() async {
    library = await LibraryRepository(rootBundle).load();
  });

  group('bundled library', () {
    test('every category in the index loads and passes validation', () async {
      final index = jsonDecode(await rootBundle.loadString('assets/library/index.json')) as Map<String, dynamic>;
      expect(library.map((c) => c.id), index['categories']);
    });

    test('has more than 100 visualizations across every chart type', () {
      final entries = library.entries.toList();
      expect(entries.length, greaterThanOrEqualTo(100));
      final byTemplate = <TemplateId, int>{};
      for (final e in entries) {
        byTemplate[e.template] = (byTemplate[e.template] ?? 0) + 1;
      }
      for (final t in TemplateId.values.where((t) => t != TemplateId.none)) {
        expect(byTemplate[t] ?? 0, greaterThanOrEqualTo(3), reason: t.wire);
      }
    });

    test('every figure has a source note and every entry renders', () {
      for (final e in library.entries) {
        for (final f in e.visualization.facts.facts) {
          expect(f.sourceNote.trim(), isNotEmpty, reason: '${e.category}/${e.id}/${f.id}');
        }
        expect(renderJson(e.visualization.props)['template'], e.template.wire);
      }
    });

    test('entries survive a share link round trip', () {
      for (final e in library.entries) {
        final decoded = ShareCodec.decode(ShareCodec.encode(e.visualization));
        expect(decoded.isValid, isTrue, reason: '${e.category}/${e.id}');
      }
    });
  });

  group('library screens', () {
    setUp(() {
      VisualizeController.renderHold = Duration.zero;
      ambientMotionEnabled = false;
    });

    Future<void> pumpApp(WidgetTester tester, {String initialLocation = '/'}) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          libraryProvider.overrideWith((ref) async => library),
          explainBackendProvider.overrideWithValue(FakeServer().client()),
          apiKeyStoreProvider.overrideWithValue(MemoryApiKeyStore()),
          fakeVizOverride,
        ],
        child: FactvizApp(initialLocation: initialLocation),
      ));
      await advance(tester, const Duration(milliseconds: 600));
    }

    testWidgets('home links to the library, which works without a key', (tester) async {
      await pumpApp(tester);
      final total = library.entries.length;
      final browse = find.text('Browse all $total visualizations');
      await tester.scrollUntilVisible(browse, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(browse);
      await advance(tester, const Duration(milliseconds: 600));
      expect(find.text('$total visualizations, ready to explore'), findsOneWidget);
    });

    testWidgets('search filters entries and an entry opens its chart', (tester) async {
      await pumpApp(tester, initialLocation: '/library');
      final entry = library.first.entries.first;
      await tester.enterText(find.byType(TextField), entry.title);
      await advance(tester, const Duration(milliseconds: 300));
      expect(find.text(entry.query), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzzz-no-such-thing');
      await advance(tester, const Duration(milliseconds: 300));
      expect(find.text('Nothing matches that search.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), entry.title);
      await advance(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text(entry.query));
      await advance(tester, const Duration(seconds: 1));
      expect(find.textContaining('viz:${entry.template.wire}#'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(entry.query)), findsOneWidget);
    });

    testWidgets('category chips narrow the list', (tester) async {
      final last = library.last;
      await pumpApp(tester, initialLocation: '/library?c=${last.id}');
      expect(find.text('${last.title} · ${last.entries.length}'.toUpperCase()), findsOneWidget);
      expect(find.text('${library.first.title} · ${library.first.entries.length}'.toUpperCase()), findsNothing);
    });

    testWidgets('an unknown library entry shows an error', (tester) async {
      await pumpApp(tester, initialLocation: '/library/space/no_such_entry');
      expect(find.text("This library entry isn't available."), findsOneWidget);
    });
  });
}
