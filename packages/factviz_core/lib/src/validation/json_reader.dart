import 'validation.dart';

/// Reads fields from an untrusted JSON object, recording a [ValidationIssue]
/// for every problem instead of throwing. Every accessor returns `null` when
/// the field is missing or invalid.
class JsonReader {
  JsonReader._(this._issues, this.path, this._map);

  /// Wraps [value] if it is a JSON object, otherwise records an issue.
  static JsonReader? of(
    Object? value,
    List<ValidationIssue> issues, [
    String path = '',
  ]) {
    if (value is Map && value.keys.every((k) => k is String)) {
      return JsonReader._(issues, path, value.cast<String, Object?>());
    }
    issues.add(ValidationIssue(path, 'expected an object'));
    return null;
  }

  final List<ValidationIssue> _issues;
  final String path;
  final Map<String, Object?> _map;

  String childPath(String key) => path.isEmpty ? key : '$path.$key';

  void issue(String message, {String? key}) =>
      _issues.add(ValidationIssue(key == null ? path : childPath(key), message));

  bool has(String key) => _map[key] != null;

  Object? _get(String key, bool optional) {
    final v = _map[key];
    if (v == null && !optional) issue('is required', key: key);
    return v;
  }

  String? string(
    String key, {
    bool optional = false,
    int minLength = 1,
    int? maxLength,
    RegExp? pattern,
    String? patternHint,
  }) {
    final v = _get(key, optional);
    if (v == null) return null;
    if (v is! String) {
      issue('expected a string', key: key);
      return null;
    }
    final s = v.trim();
    if (s.isEmpty && optional) return null;
    if (s.length < minLength) {
      issue(
        minLength == 1 ? 'must not be empty' : 'must be at least $minLength characters',
        key: key,
      );
      return null;
    }
    if (maxLength != null && s.length > maxLength) {
      issue('must be at most $maxLength characters (got ${s.length})', key: key);
      return null;
    }
    if (pattern != null && !pattern.hasMatch(s)) {
      issue('must match ${patternHint ?? pattern.pattern}', key: key);
      return null;
    }
    return s;
  }

  double? number(
    String key, {
    bool optional = false,
    double? min,
    double? max,
  }) {
    final v = _get(key, optional);
    if (v == null) return null;
    if (v is! num || !v.isFinite) {
      issue('expected a finite number', key: key);
      return null;
    }
    final d = v.toDouble();
    if (min != null && d < min) {
      issue('must be ≥ $min (got $d)', key: key);
      return null;
    }
    if (max != null && d > max) {
      issue('must be ≤ $max (got $d)', key: key);
      return null;
    }
    return d;
  }

  int? integer(String key, {bool optional = false, int? min, int? max}) {
    final v = _get(key, optional);
    if (v == null) return null;
    if (v is! num || !v.isFinite || v != v.roundToDouble()) {
      issue('expected an integer', key: key);
      return null;
    }
    final i = v.toInt();
    if (min != null && i < min) {
      issue('must be ≥ $min (got $i)', key: key);
      return null;
    }
    if (max != null && i > max) {
      issue('must be ≤ $max (got $i)', key: key);
      return null;
    }
    return i;
  }

  bool? boolean(String key, {bool optional = false}) {
    final v = _get(key, optional);
    if (v == null) return null;
    if (v is! bool) {
      issue('expected true or false', key: key);
      return null;
    }
    return v;
  }

  /// Reads a string that must be one of [options]' keys.
  T? choice<T>(String key, Map<String, T> options, {bool optional = false}) {
    final v = _get(key, optional);
    if (v == null) return null;
    final match = v is String ? options[v.trim()] : null;
    if (match == null) {
      issue('must be one of: ${options.keys.join(', ')}', key: key);
    }
    return match;
  }

  JsonReader? object(String key, {bool optional = false}) {
    final v = _get(key, optional);
    if (v == null) return null;
    return JsonReader.of(v, _issues, childPath(key));
  }

  List<Object?>? _list(String key, bool optional, int minItems, int? maxItems) {
    final v = _get(key, optional);
    if (v == null) return null;
    if (v is! List) {
      issue('expected an array', key: key);
      return null;
    }
    if (v.length < minItems) {
      issue('must have at least $minItems items (got ${v.length})', key: key);
      return null;
    }
    if (maxItems != null && v.length > maxItems) {
      issue('must have at most $maxItems items (got ${v.length})', key: key);
      return null;
    }
    return v;
  }

  /// Reads an array of objects, parsing each with [parse]. Items that fail
  /// to parse are dropped; their issues are recorded.
  List<T>? objects<T>(
    String key,
    T? Function(JsonReader item) parse, {
    bool optional = false,
    int minItems = 0,
    int? maxItems,
  }) {
    final raw = _list(key, optional, minItems, maxItems);
    if (raw == null) return null;
    final out = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final r = JsonReader.of(raw[i], _issues, '${childPath(key)}[$i]');
      if (r == null) continue;
      final item = parse(r);
      if (item != null) out.add(item);
    }
    return out;
  }

  List<String>? strings(
    String key, {
    bool optional = false,
    int minItems = 0,
    int? maxItems,
    int maxLength = 200,
  }) {
    final raw = _list(key, optional, minItems, maxItems);
    if (raw == null) return null;
    final out = <String>[];
    for (var i = 0; i < raw.length; i++) {
      final v = raw[i];
      final p = '${childPath(key)}[$i]';
      if (v is! String || v.trim().isEmpty) {
        _issues.add(ValidationIssue(p, 'expected a non-empty string'));
      } else if (v.length > maxLength) {
        _issues.add(ValidationIssue(p, 'must be at most $maxLength characters'));
      } else {
        out.add(v.trim());
      }
    }
    return out;
  }
}
