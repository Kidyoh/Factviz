import 'dart:convert';

import 'package:archive/archive.dart';

import '../facts/facts.dart';
import '../mapping/plan_resolver.dart';
import '../plan/plan.dart';
import '../validation/json_reader.dart';
import '../validation/validation.dart';
import 'visualization.dart';

/// Encodes a validated visualization into a compact, URL-safe payload and
/// back, so shared links re-render without another LLM call.
///
/// Links look like `factviz://app/v/<payload>`. Decoding re-runs the same
/// validation and resolution as a fresh result, so a tampered link can never
/// render unvalidated data.
class ShareCodec {
  const ShareCodec._();

  static const int version = 1;
  static const String scheme = 'factviz';
  static const String host = 'app';
  static const String routePrefix = '/v/';

  /// Guards against oversized or zip-bomb payloads.
  static const int maxPayloadChars = 32 * 1024;
  static const int maxDecodedBytes = 256 * 1024;

  static String encode(Visualization viz) {
    final json = jsonEncode({'v': version, 'facts': viz.facts.toJson(), 'plan': viz.plan.toJson()});
    final gz = const GZipEncoder().encodeBytes(utf8.encode(json));
    return base64Url.encode(gz).replaceAll('=', '');
  }

  static Uri link(Visualization viz) =>
      Uri(scheme: scheme, host: host, path: '$routePrefix${encode(viz)}');

  /// Extracts the payload from a share link or app route, or null.
  static String? payloadFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final i = segments.indexOf('v');
    if (i < 0 || i + 1 >= segments.length) return null;
    return segments[i + 1];
  }

  static ValidationResult<Visualization> decode(
    String payload, {
    PlanResolver resolver = const PlanResolver(),
  }) {
    final Object? json;
    try {
      if (payload.isEmpty || payload.length > maxPayloadChars) throw const FormatException('size');
      final bytes = base64Url.decode(base64Url.normalize(payload));
      final raw = const GZipDecoder().decodeBytes(bytes);
      if (raw.length > maxDecodedBytes) throw const FormatException('too large');
      json = jsonDecode(utf8.decode(raw));
    } catch (_) {
      return const Invalid([ValidationIssue('', 'this share link is damaged or incomplete')]);
    }

    final issues = <ValidationIssue>[];
    final r = JsonReader.of(json, issues);
    if (r == null) return Invalid(issues);
    final v = r.integer('v');
    if (v != null && v != version) {
      return Invalid([ValidationIssue('v', 'unsupported share link version $v')]);
    }
    final facts = FactsResult.fromJson((json as Map)['facts']);
    final plan = Plan.fromJson(json['plan']);
    issues
      ..addAll(_prefixed('facts', facts.issues))
      ..addAll(_prefixed('plan', plan.issues));
    if (issues.isNotEmpty) return Invalid(issues);
    return Visualization.build(facts.valueOrThrow, plan.valueOrThrow, resolver: resolver);
  }

  static Iterable<ValidationIssue> _prefixed(String prefix, List<ValidationIssue> issues) =>
      issues.map((i) => ValidationIssue(i.path.isEmpty ? prefix : '$prefix.${i.path}', i.message));
}
