/// One chat message sent to the model.
class LlmMessage {
  const LlmMessage.user(this.content) : role = 'user';
  const LlmMessage.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;

  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

/// A request for a single JSON object from the model.
class LlmRequest {
  const LlmRequest({
    required this.model,
    required this.system,
    required this.messages,
    required this.schemaName,
    required this.schema,
    this.temperature = 0.2,
    this.maxTokens = 4000,
  });

  final String model;
  final String system;
  final List<LlmMessage> messages;

  /// Name and JSON Schema for structured output.
  final String schemaName;
  final Map<String, Object?> schema;
  final double temperature;
  final int maxTokens;

  LlmRequest withMessages(List<LlmMessage> messages) => LlmRequest(
        model: model,
        system: system,
        messages: messages,
        schemaName: schemaName,
        schema: schema,
        temperature: temperature,
        maxTokens: maxTokens,
      );
}

class LlmResponse {
  const LlmResponse({required this.text, this.model});

  /// Raw text content; expected to be JSON but not yet parsed.
  final String text;

  /// Model that actually served the request, if reported.
  final String? model;
}

/// Provider-agnostic LLM interface. Implementations live server-side only.
abstract interface class LlmClient {
  Future<LlmResponse> complete(LlmRequest request);
}

class LlmException implements Exception {
  const LlmException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'LlmException(${statusCode ?? '-'}): $message';
}
