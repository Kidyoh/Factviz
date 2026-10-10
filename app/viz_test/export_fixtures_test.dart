// Exports render JSON for the D3 renderer's tests and previews.
//
//   cd app && flutter test viz_test/export_fixtures_test.dart
//
// Writes viz_test/fixtures/*.json: the five fixed queries plus every mock
// sample from the Dev Gallery.
import 'dart:convert';
import 'dart:io';

import 'package:factviz/templates/mock_data.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export render fixtures', () {
    final out = Directory('viz_test/fixtures')..createSync(recursive: true);
    for (final f in out.listSync()) {
      f.deleteSync();
    }
    const resolver = PlanResolver(referenceYear: 2026);
    const encoder = JsonEncoder.withIndent('  ');

    final queries = Directory('../fixtures/queries').listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in queries) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final props = resolver
          .resolve(Plan.fromJson(json['plan']).valueOrThrow, FactsResult.fromJson(json['facts']).valueOrThrow)
          .valueOrThrow;
      final name = file.uri.pathSegments.last.replaceAll('.json', '');
      File('${out.path}/query_$name.json').writeAsStringSync(encoder.convert(renderJson(props)));
    }
    for (var i = 0; i < mockSamples.length; i++) {
      final props = mockSamples[i].visualization.props;
      if (props is NoneProps) continue;
      File('${out.path}/mock_${i.toString().padLeft(2, '0')}_${props.template.wire}.json')
          .writeAsStringSync(encoder.convert(renderJson(props)));
    }
  });
}
