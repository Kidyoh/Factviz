import 'dart:async';
import 'dart:io';

import 'package:factviz_core/factviz_core.dart';
import 'package:factviz_server/pipeline.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_key_store.dart';
import 'explain_backend.dart';

/// Runs the facts → planner pipeline on the phone, calling OpenRouter with
/// the user's own key. Same prompts, validation and retry as the server.
class OnDeviceBackend implements ExplainBackend {
  OnDeviceBackend({required this.keys, http.Client? httpClient, this.baseUrl = 'https://openrouter.ai/api/v1'})
      : _http = httpClient ?? http.Client();

  final ApiKeyStore keys;
  final String baseUrl;
  final http.Client _http;

  static const needsKey = ApiException(ApiErrorKind.needsKey, 'Add your OpenRouter key to start explaining.');

  Future<ExplainPipeline> _pipeline() async {
    final key = await keys.readKey();
    if (key == null) throw needsKey;
    final model = await keys.readModel();
    final client = OpenRouterClient(
      apiKey: key,
      baseUrl: baseUrl,
      appTitle: 'Explain It Visually',
      httpClient: _http,
      timeout: const Duration(seconds: 60),
    );
    return ExplainPipeline(llm: client, factsModel: model, plannerModel: model);
  }

  @override
  Future<FactsResult> fetchFacts(String query) => _guard(() async => _unwrap(await (await _pipeline()).facts(query)));

  @override
  Future<Plan> fetchPlan(FactsResult facts) => _guard(() async => _unwrap(await (await _pipeline()).plan(facts)));

  T _unwrap<T>(PipelineResult<T> r) => switch (r) {
        PipelineOk(:final value) => value,
        PipelineRejected(kind: RejectionKind.badRequest, :final message) =>
          throw ApiException(ApiErrorKind.badRequest, message),
        PipelineRejected() => throw ApiException.unvisualizable,
      };

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on LlmException catch (e) {
      throw mapLlmError(e);
    } on SocketException {
      throw _offline;
    } on http.ClientException {
      throw _offline;
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.network, 'This is taking too long. Please try again.');
    }
  }

  static const _offline =
      ApiException(ApiErrorKind.network, "Can't reach OpenRouter. Check your internet connection and try again.");

  @override
  void close() => _http.close();
}

/// Turns provider errors into messages a person can act on.
ApiException mapLlmError(LlmException e) {
  switch (e.statusCode) {
    case 401:
    case 403:
      return const ApiException(ApiErrorKind.needsKey, 'OpenRouter rejected your key. Check it in Settings.');
    case 402:
      return const ApiException(ApiErrorKind.server, 'Your OpenRouter account is out of credits. Add credits and try again.');
    case 404:
      return const ApiException(ApiErrorKind.server, 'That model is not available on OpenRouter. Pick another in Settings.');
    case 429:
      return const ApiException(ApiErrorKind.rateLimited, "You're going a bit fast. Wait a minute and try again.");
    case null:
      return ApiException(ApiErrorKind.network,
          e.message.contains('too long') ? 'This is taking too long. Please try again.' : "Can't reach OpenRouter. Check your connection.");
    default:
      return const ApiException(ApiErrorKind.server, 'The AI service had a problem. Please try again.');
  }
}

/// Result of checking a key against OpenRouter.
enum KeyCheck { valid, invalid, unreachable }

/// Verifies a key with OpenRouter's key endpoint (no model call, no cost).
Future<KeyCheck> checkOpenRouterKey(String key, {http.Client? httpClient}) async {
  final client = httpClient ?? http.Client();
  try {
    final res = await client
        .get(Uri.parse('https://openrouter.ai/api/v1/key'), headers: {'Authorization': 'Bearer ${key.trim()}'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) return KeyCheck.valid;
    if (res.statusCode == 401 || res.statusCode == 403) return KeyCheck.invalid;
    return KeyCheck.unreachable;
  } on Exception {
    return KeyCheck.unreachable;
  } finally {
    if (httpClient == null) client.close();
  }
}
