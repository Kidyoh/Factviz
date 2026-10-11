/// The LLM pipeline without the HTTP server: provider client, prompts,
/// validation with retry. Safe to use from Flutter (the app's on-device mode).
library;

export 'src/llm/llm_client.dart';
export 'src/llm/openrouter_client.dart';
export 'src/llm/prompts/facts_prompt.dart';
export 'src/llm/prompts/planner_prompt.dart';
export 'src/pipeline/explain_pipeline.dart';
export 'src/pipeline/validated_call.dart';
