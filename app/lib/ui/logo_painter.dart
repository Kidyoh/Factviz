import 'package:flutter/rendering.dart';

import '../app/theme.dart';

/// The mark: a large and a small circle resting on one baseline, the idea of
/// comparing things to scale. Same shapes as assets/lottie/logo.json.
class LogoPainter extends CustomPainter {
  const LogoPainter({this.background = false});

  /// Paints a paper background (launcher icon).
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (background) canvas.drawRect(Offset.zero & size, Paint()..color = Palette.paper);
    final ox = (size.width - s) / 2, oy = (size.height - s) / 2;
    Offset at(double x, double y) => Offset(ox + x * s, oy + y * s);
    final base = 0.75;
    canvas.drawCircle(at(0.367, base - 0.217), 0.217 * s, Paint()..color = Palette.ink);
    canvas.drawCircle(at(0.717, base - 0.075), 0.075 * s, Paint()..color = Palette.accent);
    canvas.drawLine(at(0.1, base), at(0.9, base), Paint()
      ..color = Palette.ink
      ..strokeWidth = 0.025 * s);
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.background != background;
}
