// Validates library category files with the same checks as live answers.
//
//   dart run tool/check_library.dart ../../app/assets/library/space.json [...]
//   dart run tool/check_library.dart --export=out/ <files>   also writes render JSON
import 'dart:convert';
import 'dart:io';

import 'package:factviz_core/factviz_core.dart';

void main(List<String> args) {
  var failed = false;
  final export = args.where((a) => a.startsWith('--export=')).map((a) => a.substring(9)).firstOrNull;
  for (final path in args.where((a) => !a.startsWith('--'))) {
    final Object? json;
    try {
      json = jsonDecode(File(path).readAsStringSync());
    } on FormatException catch (e) {
      stdout.writeln('$path: invalid JSON: ${e.message}');
      failed = true;
      continue;
    }
    switch (LibraryCategory.fromJson(json)) {
      case Valid(:final value):
        final counts = <String, int>{};
        for (final e in value.entries) {
          final json = renderJson(e.visualization.props); // must not throw
          if (export != null) {
            File('$export/${value.id}_${e.id}.json')
              ..createSync(recursive: true)
              ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(json));
          }
          counts[e.template.wire] = (counts[e.template.wire] ?? 0) + 1;
        }
        stdout.writeln('$path: OK, ${value.entries.length} entries ${jsonEncode(counts)}');
      case Invalid(:final issues):
        failed = true;
        stdout.writeln('$path: ${issues.length} issue(s)');
        for (final i in issues) {
          stdout.writeln('  $i');
        }
    }
  }
  exitCode = failed ? 1 : 0;
}
