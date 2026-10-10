import 'package:factviz_server/factviz_server.dart';
import 'package:test/test.dart';

void main() {
  test('defaults to OpenRouter and Gemini', () {
    final c = ServerConfig.fromEnvironment({'OPENROUTER_API_KEY': 'k'});
    expect(c.provider, 'openrouter');
    expect(c.baseUrl, 'https://openrouter.ai/api/v1');
    expect(c.model, 'google/gemini-3.8-flash');
    expect(c.factsModelOrDefault, c.model);
    expect(c.port, 8080);
  });

  test('reads overrides', () {
    final c = ServerConfig.fromEnvironment({
      'LLM_API_KEY': 'k',
      'LLM_MODEL': 'google/gemini-3.5-flash',
      'LLM_PLANNER_MODEL': 'google/gemini-3.1-flash-lite',
      'LLM_BASE_URL': 'https://proxy.example/v1/',
      'PORT': '9000',
      'RATE_LIMIT_PER_MINUTE': '5',
      'TRUST_PROXY': 'true',
    });
    expect(c.model, 'google/gemini-3.5-flash');
    expect(c.plannerModelOrDefault, 'google/gemini-3.1-flash-lite');
    expect(c.factsModelOrDefault, 'google/gemini-3.5-flash');
    expect(c.baseUrl, 'https://proxy.example/v1');
    expect(c.port, 9000);
    expect(c.rateLimitPerMinute, 5);
    expect(c.trustProxy, isTrue);
  });

  test('requires a key and validates values', () {
    expect(() => ServerConfig.fromEnvironment({}), throwsA(isA<ConfigException>()));
    expect(() => ServerConfig.fromEnvironment({'LLM_API_KEY': 'k', 'PORT': 'eighty'}), throwsA(isA<ConfigException>()));
    expect(() => ServerConfig.fromEnvironment({'LLM_API_KEY': 'k', 'LLM_PROVIDER': 'magic'}), throwsA(isA<ConfigException>()));
    expect(
      () => ServerConfig.fromEnvironment({'LLM_API_KEY': 'k', 'LLM_PROVIDER': 'openai_compatible'}),
      throwsA(isA<ConfigException>()),
    );
  });
}
