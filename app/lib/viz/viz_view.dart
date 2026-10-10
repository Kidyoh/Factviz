import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/theme.dart';

/// Builds the widget that renders a template. The real one hosts the D3
/// renderer in a WebView; tests override it, since WebViews need a device.
typedef VizBuilder = Widget Function(BuildContext context, TemplateProps props, int replayKey);

final vizBuilderProvider = Provider<VizBuilder>(
  (ref) => (context, props, replayKey) => D3VizView(props: props, replayKey: replayKey),
);

/// Renders [props] with the matching template. Changing [replayKey]
/// restarts the animation.
class VizView extends ConsumerWidget {
  const VizView({super.key, required this.props, this.replayKey = 0});

  final TemplateProps props;
  final int replayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(vizBuilderProvider)(context, props, replayKey);
}

/// Hosts the bundled D3 renderer (assets/viz/index.html) in a WebView and
/// feeds it the template's render JSON. Everything is offline.
class D3VizView extends StatefulWidget {
  const D3VizView({super.key, required this.props, this.replayKey = 0});

  final TemplateProps props;
  final int replayKey;

  static const String asset = 'assets/viz/index.html';

  @override
  State<D3VizView> createState() => _D3VizViewState();
}

class _D3VizViewState extends State<D3VizView> {
  late final WebViewController _controller;
  bool _ready = false;
  bool _rendered = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Palette.paper)
      ..addJavaScriptChannel('FactvizBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        // The renderer never navigates; keep it that way.
        onNavigationRequest: (r) =>
            r.url.startsWith('file:') ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadFlutterAsset(D3VizView.asset);
  }

  void _onMessage(JavaScriptMessage message) {
    final Object? msg;
    try {
      msg = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'ready':
        _ready = true;
        _render();
      case 'rendered':
        if (mounted) setState(() => _rendered = true);
      case 'haptic':
        HapticFeedback.mediumImpact();
      case 'error':
        debugPrint('Viz error: ${msg['message']}');
    }
  }

  void _render() {
    if (!_ready || !mounted) return;
    final payload = jsonEncode(renderJson(widget.props));
    final options = jsonEncode({'reduceMotion': MediaQuery.disableAnimationsOf(context)});
    _controller.runJavaScript('window.FactvizViz.render($payload, $options);');
  }

  @override
  void didUpdateWidget(D3VizView old) {
    super.didUpdateWidget(old);
    if (old.props != widget.props) {
      _render();
    } else if (old.replayKey != widget.replayKey && _ready) {
      _controller.runJavaScript('window.FactvizViz.replay();');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.props.title,
      child: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(
              controller: _controller,
              // Horizontal drags (timeline, sliders) go to the chart; vertical
              // drags keep scrolling the page.
              gestureRecognizers: {Factory<HorizontalDragGestureRecognizer>(HorizontalDragGestureRecognizer.new)},
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _rendered ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              child: const ColoredBox(color: Palette.paper, child: SizedBox.expand()),
            ),
          ),
        ],
      ),
    );
  }
}
