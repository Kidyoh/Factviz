import 'package:factviz/viz/viz_view.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

/// Stand-in for the D3 WebView: widget tests run without a platform WebView.
/// Records what would have been sent to the renderer.
class FakeViz extends StatelessWidget {
  const FakeViz({super.key, required this.props, required this.replayKey});

  final TemplateProps props;
  final int replayKey;

  static final rendered = <(String template, int replayKey)>[];

  @override
  Widget build(BuildContext context) {
    // The real view serialises props for the renderer; do the same so bad
    // props fail here too.
    final json = renderJson(props);
    rendered.add((json['template']! as String, replayKey));
    return ColoredBox(
      color: const Color(0xFFEFEAE0),
      child: Center(child: Text('viz:${json['template']}#$replayKey')),
    );
  }
}

final fakeVizOverride = vizBuilderProvider.overrideWithValue(
  (context, props, replayKey) => FakeViz(props: props, replayKey: replayKey),
);
