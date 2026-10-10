import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

void main() {
  test('plan schema lists every template', () {
    final props = planJsonSchema['properties']! as Map;
    expect((props['template'] as Map)['enum'], [for (final t in TemplateId.values) t.wire]);
  });

  test('facts schema lists every allowed unit', () {
    final item = (((factsJsonSchema['properties']! as Map)['facts'] as Map)['items'] as Map)['properties'] as Map;
    expect((item['unit'] as Map)['enum'], units.keys.toList());
  });
}
