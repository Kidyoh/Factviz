import 'dart:convert';

import 'package:factviz/data/api_client.dart';
import 'package:factviz/data/api_key_store.dart';
import 'package:factviz/data/on_device_backend.dart';
import 'package:factviz/main.dart';
import 'package:factviz/state/visualize_controller.dart';
import 'package:factviz/templates/common/motion.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_server.dart';
import 'support/fake_viz.dart';
import 'support/test_app.dart';

/// A stand-in for OpenRouter's chat completions endpoint.
MockClient openRouter(List<Object> replies, {List<http.Request>? log}) {
  final queue = List.of(replies);
  return MockClient((req) async {
    log?.add(req);
    final next = queue.removeAt(0);
    if (next is http.Response) return next;
    return http.Response.bytes(
      utf8.encode(jsonEncode({
        'model': 'google/gemini-3.8-flash',
        'choices': [
          {'message': {'role': 'assistant', 'content': jsonEncode(next)}},
        ],
      })),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

http.Response orError(int status, String message) =>
    http.Response(jsonEncode({'error': {'message': message, 'code': status}}), status);

void main() {
  final f = fixture('exponential_paper_fold');

  group('OnDeviceBackend', () {
    test('runs facts then plan against OpenRouter with the stored key and model', () async {
      final log = <http.Request>[];
      final backend = OnDeviceBackend(
        keys: MemoryApiKeyStore(key: 'sk-or-v1-abc', model: 'google/gemini-3.5-flash'),
        httpClient: openRouter([f.facts, f.plan], log: log),
      );
      final facts = await backend.fetchFacts(f.query);
      final plan = await backend.fetchPlan(facts);
      expect(plan, isA<ExponentialGrowthPlan>());
      expect(log, hasLength(2));
      expect(log.first.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(log.first.headers['Authorization'], 'Bearer sk-or-v1-abc');
      expect(jsonDecode(log.first.body)['model'], 'google/gemini-3.5-flash');
    });

    test('asks for a key when none is stored, without calling OpenRouter', () async {
      final log = <http.Request>[];
      final backend = OnDeviceBackend(keys: MemoryApiKeyStore(), httpClient: openRouter([], log: log));
      await expectLater(
        backend.fetchFacts('How far is the Moon?'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.needsKey)),
      );
      expect(log, isEmpty);
    });

    test('maps OpenRouter errors to messages people can act on', () async {
      Future<ApiException> errorFor(http.Response res) async {
        final backend = OnDeviceBackend(keys: MemoryApiKeyStore(key: 'k'), httpClient: openRouter([res]));
        try {
          await backend.fetchFacts('How far is the Moon?');
          fail('expected an error');
        } on ApiException catch (e) {
          return e;
        }
      }

      expect((await errorFor(orError(401, 'No auth'))).kind, ApiErrorKind.needsKey);
      expect((await errorFor(orError(402, 'Insufficient credits'))).message, contains('out of credits'));
      expect((await errorFor(orError(429, 'Slow down'))).kind, ApiErrorKind.rateLimited);
      expect((await errorFor(orError(500, 'Boom'))).kind, ApiErrorKind.server);
    });

    test('two invalid model outputs become the friendly fallback', () async {
      final broken = Map<String, dynamic>.of(f.facts)..remove('topic');
      final backend = OnDeviceBackend(keys: MemoryApiKeyStore(key: 'k'), httpClient: openRouter([broken, broken]));
      await expectLater(backend.fetchFacts(f.query), throwsA(same(ApiException.unvisualizable)));
    });

    test('key check uses the free key endpoint', () async {
      Future<KeyCheck> check(int status) => checkOpenRouterKey('k', httpClient: MockClient((req) async {
            expect(req.url.toString(), 'https://openrouter.ai/api/v1/key');
            return http.Response('{}', status);
          }));
      expect(await check(200), KeyCheck.valid);
      expect(await check(401), KeyCheck.invalid);
      expect(await check(503), KeyCheck.unreachable);
    });
  });

  group('app without a key', () {
    setUp(() {
      VisualizeController.renderHold = Duration.zero;
      ambientMotionEnabled = false;
    });

    testWidgets('home nudges for a key; asking leads to settings; saving retries', (tester) async {
      final store = MemoryApiKeyStore();
      final checked = <String>[];
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(store),
          explainBackendProvider.overrideWithValue(OnDeviceBackend(keys: store, httpClient: openRouter([f.facts, f.plan]))),
          keyCheckerProvider.overrideWithValue((key) async {
            checked.add(key);
            return KeyCheck.valid;
          }),
          fakeVizOverride,
        ],
        child: const FactvizApp(),
      ));
      await advance(tester, const Duration(milliseconds: 600), steps: 6);
      expect(find.textContaining('add your OpenRouter key'), findsOneWidget);

      await tester.ensureVisible(find.text('Fold a paper 42 times to reach the Moon'));
      await tester.pump();
      await tester.tap(find.text('Fold a paper 42 times to reach the Moon'));
      await advance(tester, const Duration(milliseconds: 800), steps: 8);
      expect(find.text('Add your OpenRouter key to start explaining.'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await advance(tester, const Duration(milliseconds: 600), steps: 6);
      expect(find.text('Connect OpenRouter'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '  sk-or-v1-secret  ');
      await tester.tap(find.text('Save'));
      await advance(tester, const Duration(milliseconds: 300), steps: 3);
      expect(store.key, 'sk-or-v1-secret');
      expect(checked, ['sk-or-v1-secret']);
      expect(find.text('Key saved and verified with OpenRouter.'), findsOneWidget);

      // Back to the result, which retries with the new key.
      await tester.tap(find.byTooltip('Back'));
      await advance(tester, const Duration(seconds: 1), steps: 10);
      expect(find.text('viz:exponential_growth#0'), findsOneWidget);
    });

    testWidgets('a rejected key is not saved', (tester) async {
      final store = MemoryApiKeyStore();
      await pumpPhoneScoped(tester, store, KeyCheck.invalid);
      await tester.enterText(find.byType(TextField).first, 'bad-key');
      await tester.tap(find.text('Save'));
      await advance(tester, const Duration(milliseconds: 300), steps: 3);
      expect(store.key, isNull);
      expect(find.textContaining('did not accept that key'), findsOneWidget);
    });
  });
}

Future<void> pumpPhoneScoped(WidgetTester tester, MemoryApiKeyStore store, KeyCheck result) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiKeyStoreProvider.overrideWithValue(store),
      keyCheckerProvider.overrideWithValue((_) async => result),
      fakeVizOverride,
    ],
    child: const FactvizApp(initialLocation: '/settings'),
  ));
  await advance(tester, const Duration(milliseconds: 300), steps: 3);
}
