import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_client.dart';

/// Client for OpenRouter and other OpenAI-compatible chat completion APIs.
///
/// Requests structured output with a JSON Schema. If the routed provider
/// rejects the schema (HTTP 400), retries once in plain JSON mode; the
/// schema is also described in the prompt, and the server validates the
/// result either way.
class OpenRouterClient implements LlmClient {
  OpenRouterClient({
    required this.apiKey,
    required this.baseUrl,
    http.Client? httpClient,
    this.appUrl,
    this.appTitle,
    this.timeout = const Duration(seconds: 60),
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final String? appUrl;
  final String? appTitle;
  final Duration timeout;
  final http.Client _http;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    try {
      return await _send(request, structured: true);
    } on LlmException catch (e) {
      if (e.statusCode != 400) rethrow;
      return _send(request, structured: false);
    }
  }

  Future<LlmResponse> _send(LlmRequest request, {required bool structured}) async {
    final body = {
      'model': request.model,
      'messages': [
        {'role': 'system', 'content': request.system},
        for (final m in request.messages) m.toJson(),
      ],
      'temperature': request.temperature,
      'max_tokens': request.maxTokens,
      'response_format': structured
          ? {
              'type': 'json_schema',
              'json_schema': {'name': request.schemaName, 'strict': false, 'schema': request.schema},
            }
          : {'type': 'json_object'},
      // Only route to providers that honour response_format.
      'provider': {'require_parameters': true},
    };

    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': ?appUrl,
              'X-Title': ?appTitle,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LlmException('the model took too long to respond');
    } on http.ClientException catch (e) {
      throw LlmException('network error: ${e.message}');
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw LlmException('provider returned a non-JSON body', statusCode: res.statusCode);
    }

    final error = json is Map ? json['error'] : null;
    if (res.statusCode != 200 || error != null) {
      final message = error is Map ? '${error['message'] ?? error}' : 'HTTP ${res.statusCode}';
      final code = error is Map && error['code'] is int ? error['code'] as int : res.statusCode;
      throw LlmException(message, statusCode: code);
    }

    final choices = json is Map ? json['choices'] : null;
    final message = choices is List && choices.isNotEmpty && choices.first is Map ? choices.first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const LlmException('provider returned an empty response');
    }
    return LlmResponse(text: content, model: json is Map ? json['model'] as String? : null);
  }

  void close() => _http.close();
}
