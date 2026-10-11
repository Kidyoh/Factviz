/// Explain It Visually API server.
library;

import 'package:shelf/shelf.dart';

import 'src/config.dart';
import 'src/llm/llm_client.dart';
import 'src/llm/openrouter_client.dart';
import 'src/routes/api.dart';
import 'src/routes/rate_limit.dart';

export 'src/config.dart';
export 'src/llm/llm_client.dart';
export 'src/llm/openrouter_client.dart';
export 'src/llm/prompts/facts_prompt.dart';
export 'src/llm/prompts/planner_prompt.dart';
export 'src/pipeline/explain_pipeline.dart';
export 'src/pipeline/validated_call.dart';
export 'src/routes/api.dart';
export 'src/routes/rate_limit.dart';

/// Builds the full request handler. Pass [llm] to override the provider
/// client (tests).
Handler buildHandler(ServerConfig config, {LlmClient? llm, Logger? log, bool accessLog = true}) {
  final client = llm ??
      OpenRouterClient(
        apiKey: config.apiKey,
        baseUrl: config.baseUrl,
        appUrl: config.appUrl,
        appTitle: config.appTitle,
        timeout: config.requestTimeout,
      );
  final api = FactvizApi(
    llm: client,
    factsModel: config.factsModelOrDefault,
    plannerModel: config.plannerModelOrDefault,
    log: log,
  );
  var pipeline = const Pipeline();
  if (accessLog) pipeline = pipeline.addMiddleware(logRequests());
  return pipeline
      .addMiddleware(rateLimit(perMinute: config.rateLimitPerMinute, trustProxy: config.trustProxy))
      .addHandler(api.handler);
}
