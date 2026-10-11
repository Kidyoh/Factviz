import 'dart:convert';
import 'dart:io';

import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

/// The bundled library in the app must pass the same checks as live answers.
void main() {
  final dir = Directory('../../app/assets/library');
  final index = jsonDecode(File('${dir.path}/index.json').readAsStringSync()) as Map<String, dynamic>;
  final ids = (index['categories'] as List).cast<String>();

  test('index lists every category file', () {
    final files = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n != 'index.json');
    expect(files.map((n) => n.replaceAll('.json', '')).toSet(), ids.toSet());
  });

  for (final id in ids) {
    test('library category "$id" is valid', () {
      final result = LibraryCategory.fromJson(jsonDecode(File('${dir.path}/$id.json').readAsStringSync()));
      expect(result.issues, isEmpty);
      final category = result.valueOrThrow;
      expect(category.id, id);
      for (final e in category.entries) {
        expect(e.visualization.plan.template, isNot(TemplateId.none), reason: e.id);
        expect(renderJson(e.visualization.props), containsPair('template', e.template.wire));
      }
    });
  }

  test('LibraryCategory reports entry paths for bad data', () {
    final result = LibraryCategory.fromJson({
      'category': 'x',
      'title': 'X',
      'entries': [
        {
          'id': 'bad',
          'facts': {'query': 'q', 'topic': 't', 'confidence': 'high', 'explanation': 'e', 'facts': []},
          'plan': {'template': 'donut', 'title': 'T', 'items': []},
        },
      ],
    });
    expect(result.issues.map((i) => i.path), containsAll(['entries[0].facts.facts', 'entries[0].plan.items']));
  });
}
