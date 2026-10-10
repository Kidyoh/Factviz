/// Server settings, read from environment variables.
class ServerConfig {
  const ServerConfig({
    required this.apiKey,
    this.provider = 'openrouter',
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
    this.factsModel,
    this.plannerModel,
    this.appUrl,
    this.appTitle = 'Explain It Visually',
    this.port = 8080,
    this.requestTimeout = const Duration(seconds: 60),
    this.rateLimitPerMinute = 20,
    this.trustProxy = false,
  });

  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel = 'google/gemini-3.8-flash';

  /// Secret key for the LLM provider. Never sent to the app.
  final String apiKey;

  /// `openrouter` (default) or `openai_compatible` with a custom [baseUrl].
  final String provider;
  final String baseUrl;

  /// Model used for both layers unless overridden.
  final String model;
  final String? factsModel;
  final String? plannerModel;

  /// Sent to OpenRouter as HTTP-Referer / X-Title for attribution.
  final String? appUrl;
  final String appTitle;

  final int port;
  final Duration requestTimeout;

  /// Requests per minute per client IP for the /api routes. 0 disables.
  final int rateLimitPerMinute;

  /// Use X-Forwarded-For for client IPs (set when behind a load balancer).
  final bool trustProxy;

  String get factsModelOrDefault => factsModel ?? model;
  String get plannerModelOrDefault => plannerModel ?? model;

  static ServerConfig fromEnvironment(Map<String, String> env) {
    String? read(String key) {
      final v = env[key]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    final provider = read('LLM_PROVIDER') ?? 'openrouter';
    if (provider != 'openrouter' && provider != 'openai_compatible') {
      throw ConfigException('LLM_PROVIDER must be "openrouter" or "openai_compatible" (got "$provider")');
    }
    final apiKey = read('LLM_API_KEY') ?? read('OPENROUTER_API_KEY');
    if (apiKey == null) {
      throw const ConfigException('Set LLM_API_KEY (or OPENROUTER_API_KEY) to your provider key');
    }
    final baseUrl = read('LLM_BASE_URL') ?? (provider == 'openrouter' ? defaultBaseUrl : null);
    if (baseUrl == null) throw const ConfigException('LLM_BASE_URL is required for openai_compatible');

    int intOf(String key, int fallback) {
      final v = read(key);
      if (v == null) return fallback;
      return int.tryParse(v) ?? (throw ConfigException('$key must be an integer (got "$v")'));
    }

    return ServerConfig(
      apiKey: apiKey,
      provider: provider,
      baseUrl: baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      model: read('LLM_MODEL') ?? defaultModel,
      factsModel: read('LLM_FACTS_MODEL'),
      plannerModel: read('LLM_PLANNER_MODEL'),
      appUrl: read('APP_URL'),
      appTitle: read('APP_TITLE') ?? 'Explain It Visually',
      port: intOf('PORT', 8080),
      requestTimeout: Duration(seconds: intOf('LLM_TIMEOUT_SECONDS', 60)),
      rateLimitPerMinute: intOf('RATE_LIMIT_PER_MINUTE', 20),
      trustProxy: read('TRUST_PROXY') == 'true',
    );
  }
}

class ConfigException implements Exception {
  const ConfigException(this.message);
  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
