import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:shelf/shelf.dart';

import '../llm/llm_client.dart';
import '../pipeline/explain_pipeline.dart';

typedef Logger = void Function(String message);

/// HTTP API: `POST /api/facts`, `POST /api/plan`, `GET /healthz`.
class FactvizApi {
  FactvizApi({
    required this.llm,
    required this.factsModel,
    required this.plannerModel,
    this.resolver = const PlanResolver(),
    Logger? log,
  }) : _log = log ?? print;

  final LlmClient llm;
  final String factsModel;
  final String plannerModel;
  final PlanResolver resolver;
  final Logger _log;

  static const int maxBodyBytes = 64 * 1024;

  Handler get handler => (Request request) async {
        try {
          return await _route(request);
        } on LlmException catch (e) {
          _log('upstream error: $e');
          return _error(502, 'upstream', 'The fact service is unavailable right now. Please try again.');
        } catch (e, st) {
          _log('unhandled error: $e\n$st');
          return _error(500, 'internal', 'Something went wrong. Please try again.');
        }
      };

  Future<Response> _route(Request request) async {
    final path = request.url.path;
    if (path == 'healthz') {
      return request.method == 'GET' ? Response.ok('ok') : _error(405, 'method_not_allowed', 'Use GET.');
    }
    if (path != 'api/facts' && path != 'api/plan') return _error(404, 'not_found', 'Not found.');
    if (request.method != 'POST') return _error(405, 'method_not_allowed', 'Use POST.');

    final body = await _readJson(request);
    if (body == null) return _error(400, 'bad_request', 'Send a JSON object body.');
    return path == 'api/facts' ? _facts(body) : _plan(body);
  }

  late final ExplainPipeline _pipeline = ExplainPipeline(
    llm: llm,
    factsModel: factsModel,
    plannerModel: plannerModel,
    resolver: resolver,
    log: _log,
  );

  Future<Response> _facts(Map<String, Object?> body) async {
    final raw = body['query'];
    return _respond('facts', await _pipeline.facts(raw is String ? raw : ''), (f) => f.toJson());
  }

  Future<Response> _plan(Map<String, Object?> body) async {
    switch (FactsResult.fromJson(body['facts'])) {
      case Invalid(:final issues):
        return _error(400, 'bad_request', 'The facts sent were not valid.', issues: issues);
      case Valid(value: final facts):
        return _respond('plan', await _pipeline.plan(facts), (p) => p.toJson());
    }
  }

  Response _respond<T>(String key, PipelineResult<T> result, Object Function(T) toJson) => switch (result) {
        PipelineOk(:final value, :final attempts) => _json(200, {key: toJson(value), 'meta': {'attempts': attempts}}),
        PipelineRejected(kind: RejectionKind.badRequest, :final message) => _error(400, 'bad_request', message),
        PipelineRejected(:final message, :final issues) => _error(422, 'unvisualizable', message, issues: issues),
      };

  Future<Map<String, Object?>?> _readJson(Request request) async {
    final length = request.contentLength;
    if (length != null && length > maxBodyBytes) return null;
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxBodyBytes) return null;
    }
    try {
      final json = jsonDecode(utf8.decode(bytes));
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  static Response _json(int status, Object body) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static Response _error(int status, String code, String message, {List<ValidationIssue>? issues}) => _json(status, {
        'error': {
          'code': code,
          'message': message,
          if (issues != null) 'details': [for (final i in issues) '$i'],
        },
      });
}
