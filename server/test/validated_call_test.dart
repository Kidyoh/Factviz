import 'package:factviz_core/factviz_core.dart';
import 'package:factviz_server/factviz_server.dart';
import 'package:test/test.dart';

import 'support/fake_llm.dart';

void main() {
  final facts = loadFixture('exponential_paper_fold')['facts'] as Map<String, dynamic>;
  LlmRequest request() => buildFactsRequest(model: 'm', query: 'q');

  test('returns the value on the first valid response', () async {
    final llm = FakeLlm([facts]);
    final outcome = await validatedCall(llm: llm, request: request(), validate: FactsResult.fromJson);
    expect(outcome, isA<CallSucceeded<FactsResult>>().having((o) => o.attempts, 'attempts', 1));
    expect(llm.requests, hasLength(1));
  });

  test('retries once with the validation errors fed back', () async {
    final broken = clone(facts)..remove('topic');
    final llm = FakeLlm([broken, facts]);
    final outcome = await validatedCall(llm: llm, request: request(), validate: FactsResult.fromJson);
    expect(outcome, isA<CallSucceeded<FactsResult>>().having((o) => o.attempts, 'attempts', 2));

    final retry = llm.requests[1].messages;
    expect(retry, hasLength(3));
    expect(retry[1].role, 'assistant');
    expect(retry[2].role, 'user');
    expect(retry[2].content, 'Your previous output failed validation:\n- topic: is required\nReturn the corrected JSON object only.');
  });

  test('gives up after two invalid responses', () async {
    final broken = clone(facts)..['confidence'] = 'certain';
    final llm = FakeLlm([broken, broken]);
    final outcome = await validatedCall(llm: llm, request: request(), validate: FactsResult.fromJson);
    expect(outcome, isA<CallFailedValidation<FactsResult>>());
    expect((outcome as CallFailedValidation).issues.single.toString(),
        'confidence: must be one of: high, medium, low');
    expect(llm.requests, hasLength(2));
  });

  test('treats non-JSON output as a validation failure', () async {
    final llm = FakeLlm(['Sure! Here are the facts you asked for.', facts]);
    final outcome = await validatedCall(llm: llm, request: request(), validate: FactsResult.fromJson);
    expect(outcome, isA<CallSucceeded<FactsResult>>());
    expect(llm.requests[1].messages.last.content, contains('output was not valid JSON'));
  });

  group('decodeModelJson', () {
    test('accepts plain JSON, fenced JSON and JSON wrapped in prose', () {
      expect(decodeModelJson('{"a":1}').$1, {'a': 1});
      expect(decodeModelJson('```json\n{"a":1}\n```').$1, {'a': 1});
      expect(decodeModelJson('```\n{"a":1}\n```').$1, {'a': 1});
      expect(decodeModelJson('Here you go: {"a":1} hope that helps').$1, {'a': 1});
    });

    test('reports garbage', () {
      final (json, error) = decodeModelJson('not json at all');
      expect(json, isNull);
      expect(error, isNotNull);
    });
  });
}
