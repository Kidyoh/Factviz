import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:factviz_core/factviz_core.dart';
import 'package:http/http.dart' as http;

/// API server address, set at build time:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
/// Defaults to the host machine as seen from the Android emulator.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

enum ApiErrorKind { network, unvisualizable, rateLimited, badRequest, server }

class ApiException implements Exception {
  const ApiException(this.kind, this.message);

  final ApiErrorKind kind;

  /// Friendly, user-facing message.
  final String message;

  bool get canRetry => kind != ApiErrorKind.badRequest;

  static const unvisualizable =
      ApiException(ApiErrorKind.unvisualizable, "Couldn't visualize this one, try rephrasing.");

  @override
  String toString() => 'ApiException(${kind.name}): $message';
}

/// Talks to the Explain It Visually server. Holds no secrets: the LLM key
/// lives on the server.
class FactvizApiClient {
  FactvizApiClient({String baseUrl = apiBaseUrl, http.Client? httpClient, this.timeout = const Duration(seconds: 130)})
      : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;
  final Duration timeout;

  /// Step 1: facts for [query], validated again on the device.
  Future<FactsResult> fetchFacts(String query) async {
    final json = await _post('/api/facts', {'query': query});
    return switch (FactsResult.fromJson(json['facts'])) {
      Valid(:final value) => value,
      Invalid() => throw ApiException.unvisualizable,
    };
  }

  /// Step 2: a template plan for [facts].
  Future<Plan> fetchPlan(FactsResult facts) async {
    final json = await _post('/api/plan', {'facts': facts.toJson()});
    return switch (Plan.fromJson(json['plan'])) {
      Valid(:final value) => value,
      Invalid() => throw ApiException.unvisualizable,
    };
  }

  Future<Map<String, Object?>> _post(String path, Object body) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$_base$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.network, 'This is taking too long. Please try again.');
    } on SocketException {
      throw _offline;
    } on http.ClientException {
      throw _offline;
    }

    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, Object?>) json = decoded;
    } on FormatException {
      json = null;
    }

    if (res.statusCode == 200 && json != null) return json;
    final error = json?['error'];
    final serverMessage = error is Map && error['message'] is String ? error['message'] as String : null;
    throw switch (res.statusCode) {
      422 => ApiException.unvisualizable,
      429 => const ApiException(ApiErrorKind.rateLimited, "You're going a bit fast. Wait a minute and try again."),
      400 => ApiException(ApiErrorKind.badRequest, serverMessage ?? 'Please rephrase your question.'),
      _ => const ApiException(ApiErrorKind.server, 'Something went wrong on our side. Please try again.'),
    };
  }

  static const _offline =
      ApiException(ApiErrorKind.network, "Can't reach the server. Check your connection and try again.");

  void close() => _http.close();
}
