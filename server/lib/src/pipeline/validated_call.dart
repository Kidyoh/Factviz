import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';

import '../llm/llm_client.dart';

/// Result of an LLM call whose output had to pass validation.
sealed class CallOutcome<T> {
  const CallOutcome(this.attempts);

  /// Number of LLM requests made (1 or 2).
  final int attempts;
}

final class CallSucceeded<T> extends CallOutcome<T> {
  const CallSucceeded(this.value, super.attempts);
  final T value;
}

final class CallFailedValidation<T> extends CallOutcome<T> {
  const CallFailedValidation(this.issues, super.attempts);

  /// Issues from the last attempt.
  final List<ValidationIssue> issues;
}

/// Feedback sent to the model after a failed attempt.
String retryPrompt(List<ValidationIssue> issues) =>
    'Your previous output failed validation:\n${formatIssues(issues)}\n'
    'Return the corrected JSON object only.';

/// Calls the model, validates its JSON, and on failure retries once with the
/// validation errors fed back.
Future<CallOutcome<T>> validatedCall<T>({
  required LlmClient llm,
  required LlmRequest request,
  required ValidationResult<T> Function(Object? json) validate,
  int maxAttempts = 2,
}) async {
  var messages = request.messages;
  var issues = const <ValidationIssue>[];
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final response = await llm.complete(request.withMessages(messages));
    final result = switch (decodeModelJson(response.text)) {
      (final Object? json, null) => validate(json),
      (_, final String error) => Invalid<T>([ValidationIssue('', error)]),
    };
    switch (result) {
      case Valid<T>(:final value):
        return CallSucceeded(value, attempt);
      case Invalid<T>(issues: final found):
        issues = found;
        messages = [
          ...messages,
          LlmMessage.assistant(response.text),
          LlmMessage.user(retryPrompt(found)),
        ];
    }
  }
  return CallFailedValidation(issues, maxAttempts);
}

/// Parses model output as JSON, tolerating markdown fences and stray prose
/// around a single object. Returns `(json, null)` or `(null, error)`.
(Object?, String?) decodeModelJson(String text) {
  var s = text.trim();
  final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(s);
  if (fence != null) s = fence.group(1)!;
  try {
    return (jsonDecode(s), null);
  } on FormatException {
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return (jsonDecode(s.substring(start, end + 1)), null);
      } on FormatException {
        // fall through
      }
    }
    return (null, 'output was not valid JSON; return a single JSON object');
  }
}
