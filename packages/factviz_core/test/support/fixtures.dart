import 'dart:convert';
import 'dart:io';

/// One of the five fixed test queries in `/fixtures/queries`.
class QueryFixture {
  QueryFixture(this.name, this.json);

  final String name;
  final Map<String, dynamic> json;

  String get query => json['query'] as String;
  String get expectedTemplate => json['expectedTemplate'] as String;
  Map<String, dynamic> get facts => json['facts'] as Map<String, dynamic>;
  Map<String, dynamic> get plan => json['plan'] as Map<String, dynamic>;
}

List<QueryFixture> loadQueryFixtures() {
  final dir = Directory('../../fixtures/queries');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      QueryFixture(
        f.uri.pathSegments.last.replaceAll('.json', ''),
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      ),
  ];
}

QueryFixture fixture(String name) => loadQueryFixtures().firstWhere((f) => f.name == name);

/// Deep copy so tests can mutate fixture JSON freely.
Map<String, dynamic> clone(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
