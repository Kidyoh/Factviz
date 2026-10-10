import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:shelf/shelf.dart';

import '../llm/llm_client.dart';
import '../llm/prompts/facts_prompt.dart';
import '../llm/prompts/planner_prompt.dart';
import '../pipeline/validated_call.dart';

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
  static const int minQueryLength = 3;
  static const int maxQueryLength = 300;
  static const String unvisualizableMessage = "Couldn't visualize this one, try rephrasing.";

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

  Future<Response> _facts(Map<String, Object?> body) async {
    final raw = body['query'];
    final query = raw is String ? raw.trim().replaceAll(RegExp(r'\s+'), ' ') : null;
    if (query == null || query.length < minQueryLength || query.length > maxQueryLength) {
      return _error(400, 'bad_request', 'Type a question between $minQueryLength and $maxQueryLength characters.');
    }

    final outcome = await validatedCall(
      llm: llm,
      request: buildFactsRequest(model: factsModel, query: query),
      validate: (json) {
        // The echoed query is always the user's own text.
        if (json is Map<String, dynamic>) json['query'] = query;
        return FactsResult.fromJson(json);
      },
    );
    switch (outcome) {
      case CallSucceeded(:final value, :final attempts):
        _log('facts ok attempts=$attempts facts=${value.facts.length} confidence=${value.confidence.name}');
        return _json(200, {'facts': value.toJson(), 'meta': {'attempts': attempts}});
      case CallFailedValidation(:final issues, :final attempts):
        _log('facts invalid after $attempts attempts:\n${formatIssues(issues)}');
        return _error(422, 'unvisualizable', unvisualizableMessage, issues: issues);
    }
  }

  Future<Response> _plan(Map<String, Object?> body) async {
    final factsResult = FactsResult.fromJson(body['facts']);
    final FactsResult facts;
    switch (factsResult) {
      case Invalid(:final issues):
        return _error(400, 'bad_request', 'The facts sent were not valid.', issues: issues);
      case Valid(:final value):
        facts = value;
    }

    if (facts.facts.isEmpty) {
      final plan = NonePlan(title: facts.topic, reason: 'There are not enough reliable facts to draw this.');
      return _json(200, {'plan': plan.toJson(), 'meta': {'attempts': 0}});
    }

    final outcome = await validatedCall<Plan>(
      llm: llm,
      request: buildPlannerRequest(model: plannerModel, facts: facts),
      validate: (json) => switch (Plan.fromJson(json)) {
        Invalid(:final issues) => Invalid(issues),
        Valid(value: final plan) => switch (resolver.resolve(plan, facts)) {
            Invalid(:final issues) => Invalid(issues),
            Valid() => Valid(plan),
          },
      },
    );
    switch (outcome) {
      case CallSucceeded(:final value, :final attempts):
        _log('plan ok attempts=$attempts template=${value.template.wire}');
        return _json(200, {'plan': value.toJson(), 'meta': {'attempts': attempts}});
      case CallFailedValidation(:final issues, :final attempts):
        _log('plan invalid after $attempts attempts:\n${formatIssues(issues)}');
        return _error(422, 'unvisualizable', unvisualizableMessage, issues: issues);
    }
  }

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
