import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../templates/common/motion.dart';
import '../../templates/common/viz_paint.dart';

/// The app's mark: a glowing planet with a tilted ring and an orbiting moon.
/// Animates unless [animate] is false or the user prefers reduced motion.
class OrbitMark extends StatefulWidget {
  const OrbitMark({super.key, this.size = 96, this.animate = true, this.speed = 1});

  final double size;
  final bool animate;

  /// Orbits per 6 seconds.
  final double speed;

  @override
  State<OrbitMark> createState() => _OrbitMarkState();
}

class _OrbitMarkState extends State<OrbitMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !widget.animate || !ambientMotionOf(context);
    if (still) {
      _c.value = 0.18;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: OrbitMarkPainter(_c, speed: widget.speed)),
      ),
    );
  }
}

class OrbitMarkPainter extends CustomPainter {
  OrbitMarkPainter(this.t, {this.speed = 1, this.background = false, this.markVisible = true}) : super(repaint: t);

  final Animation<double> t;
  final double speed;

  /// Paints a filled space background (used for the launcher icon).
  final bool background;

  /// Set false to paint only the background.
  final bool markVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    if (background) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.3, -0.4),
            radius: 1.1,
            colors: [Color(0xFF26245E), Cosmos.void1, Cosmos.void0],
            stops: [0, 0.55, 1],
          ).createShader(rect),
      );
    }

    if (!markVisible) return;
    final angle = t.value * 2 * math.pi * speed;
    final ring = Rect.fromCenter(center: c, width: s * 0.92, height: s * 0.34);
    const tilt = -0.42;
    final moonLocal = Offset(math.cos(angle) * ring.width / 2, math.sin(angle) * ring.height / 2);
    final moonPos = c + _rotate(moonLocal, tilt);
    final moonBehind = math.sin(angle) < 0;

    void drawRing({required bool back}) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      canvas.translate(-c.dx, -c.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [Cosmos.cyan, Cosmos.violet, Cosmos.pink]).createShader(ring);
      canvas.drawArc(ring, back ? math.pi : 0, math.pi, false, paint);
      canvas.restore();
    }

    drawRing(back: true);
    if (moonBehind) paintSphere(canvas, moonPos, s * 0.07, Cosmos.pink);
    paintSphere(canvas, c, s * 0.25, const Color(0xFF6C7CFF), highlight: Cosmos.cyan);
    drawRing(back: false);
    if (!moonBehind) paintSphere(canvas, moonPos, s * 0.07, Cosmos.pink);
  }

  static Offset _rotate(Offset o, double a) =>
      Offset(o.dx * math.cos(a) - o.dy * math.sin(a), o.dx * math.sin(a) + o.dy * math.cos(a));

  @override
  bool shouldRepaint(OrbitMarkPainter old) => old.speed != speed;
}
