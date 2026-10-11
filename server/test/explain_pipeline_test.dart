import 'package:factviz_core/factviz_core.dart';
import 'package:factviz_server/pipeline.dart';
import 'package:test/test.dart';

import 'support/fake_llm.dart';

void main() {
  final f = loadFixture('exponential_paper_fold');
  ExplainPipeline pipeline(FakeLlm llm) => ExplainPipeline(llm: llm, factsModel: 'm', plannerModel: 'm');

  test('normalizes queries and rejects out-of-range ones', () {
    expect(ExplainPipeline.normalizeQuery('  How   far  '), 'How far');
    expect(ExplainPipeline.normalizeQuery('hi'), isNull);
    expect(ExplainPipeline.normalizeQuery('x' * 301), isNull);
  });

  test('facts then plan, end to end', () async {
    final llm = FakeLlm([f['facts'] as Object, f['plan'] as Object]);
    final p = pipeline(llm);
    final facts = await p.facts('Fold a paper 42 times to reach the Moon');
    expect(facts, isA<PipelineOk<FactsResult>>());
    final plan = await p.plan((facts as PipelineOk<FactsResult>).value);
    expect((plan as PipelineOk<Plan>).value, isA<ExponentialGrowthPlan>());
  });

  test('bad queries never reach the model', () async {
    final llm = FakeLlm([]);
    final r = await pipeline(llm).facts('no');
    expect(r, isA<PipelineRejected<FactsResult>>().having((x) => x.kind, 'kind', RejectionKind.badRequest));
    expect(llm.requests, isEmpty);
  });

  test('two invalid outputs are unvisualizable', () async {
    final broken = clone(f['facts'] as Map<String, dynamic>)..remove('topic');
    final r = await pipeline(FakeLlm([broken, broken])).facts('Fold paper');
    expect(r, isA<PipelineRejected<FactsResult>>()
        .having((x) => x.kind, 'kind', RejectionKind.unvisualizable)
        .having((x) => x.message, 'message', "Couldn't visualize this one, try rephrasing."));
  });

  test('provider errors propagate', () async {
    final p = pipeline(FakeLlm([const LlmException('nope', statusCode: 401)]));
    expect(() => p.facts('How far is the Moon?'), throwsA(isA<LlmException>()));
  });
}
