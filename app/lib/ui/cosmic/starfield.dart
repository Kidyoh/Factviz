import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../templates/common/motion.dart';

/// Deep-space backdrop: gradient, soft nebula clouds and a slowly drifting,
/// twinkling starfield. Static when the user prefers reduced motion.
class CosmicBackground extends StatefulWidget {
  const CosmicBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// 0..1, how bright the nebula and stars are.
  final double intensity;

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 120));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !ambientMotionOf(context);
    if (still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Cosmos.void1, Cosmos.void0, Color(0xFF060A1A)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(painter: _NebulaPainter(widget.intensity)),
        ),
        RepaintBoundary(
          child: CustomPaint(painter: _StarPainter(_clock, widget.intensity)),
        ),
        widget.child,
      ],
    );
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter(this.intensity);
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset c, double r, Color color, double alpha) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: alpha * intensity),
            color.withValues(alpha: 0),
          ]).createShader(rect),
      );
    }

    final w = size.width, h = size.height;
    blob(Offset(w * 0.95, h * 0.05), w * 0.9, Cosmos.violet, 0.22);
    blob(Offset(w * -0.1, h * 0.38), w * 0.8, const Color(0xFF00A3FF), 0.13);
    blob(Offset(w * 0.75, h * 0.95), w * 0.85, Cosmos.pink, 0.10);
  }

  @override
  bool shouldRepaint(_NebulaPainter old) => old.intensity != intensity;
}

class _Star {
  _Star(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        radius = 0.35 + math.pow(r.nextDouble(), 3) * 1.5,
        alpha = 0.25 + r.nextDouble() * 0.75,
        twinkle = 0.5 + r.nextDouble() * 2.5,
        phase = r.nextDouble() * math.pi * 2,
        depth = 0.2 + r.nextDouble() * 0.8,
        tint = r.nextDouble();

  final double x, y, radius, alpha, twinkle, phase, depth, tint;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.clock, this.intensity) : super(repaint: clock);

  final Animation<double> clock;
  final double intensity;

  static final List<_Star> _stars = () {
    final r = math.Random(7);
    return List.generate(170, (_) => _Star(r));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 120; // seconds
    final paint = Paint();
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final s in _stars) {
      // Very slow drift; nearer stars move faster for depth.
      final y = (s.y + t * 0.0012 * s.depth) % 1.0;
      final o = Offset(s.x * size.width, y * size.height);
      final tw = 0.65 + 0.35 * math.sin(t * s.twinkle + s.phase);
      final a = (s.alpha * tw * intensity).clamp(0.0, 1.0);
      final color = Color.lerp(const Color(0xFFCFE6FF), const Color(0xFFFFE3F4), s.tint)!;
      if (s.radius > 1.3) {
        glow.color = color.withValues(alpha: a * 0.5);
        canvas.drawCircle(o, s.radius * 3, glow);
      }
      paint.color = color.withValues(alpha: a);
      canvas.drawCircle(o, s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.intensity != intensity;
}
