import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../templates/common/viz_paint.dart';
import 'cosmic/glass.dart';

enum ExampleArt { moon, paper, whale, planets, rocket, water }

class ExampleIdea {
  const ExampleIdea(this.prompt, this.tag, this.art, this.accent);

  final String prompt;
  final String tag;
  final ExampleArt art;
  final Color accent;
}

/// Example questions, at least one per template.
const exampleIdeas = [
  ExampleIdea('How far is the Moon?', 'Scale', ExampleArt.moon, Cosmos.cyan),
  ExampleIdea('Fold a paper 42 times to reach the Moon', 'Growth', ExampleArt.paper, Cosmos.amber),
  ExampleIdea('Blue whale vs a school bus', 'Compare', ExampleArt.whale, Cosmos.mint),
  ExampleIdea('Sizes of the planets', 'Scale', ExampleArt.planets, Cosmos.violet),
  ExampleIdea('History of human spaceflight', 'Timeline', ExampleArt.rocket, Cosmos.pink),
  ExampleIdea('How the water cycle works', 'Process', ExampleArt.water, Color(0xFF6BA8FF)),
];

final examplePrompts = [for (final e in exampleIdeas) e.prompt];

/// Two-column grid of illustrated example cards that fade in one by one.
class ExamplePrompts extends StatefulWidget {
  const ExamplePrompts({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<ExamplePrompts> createState() => _ExamplePromptsState();
}

class _ExamplePromptsState extends State<ExamplePrompts> with SingleTickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 12.0;
      final width = (constraints.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < exampleIdeas.length; i++)
            SizedBox(
              width: width,
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(((_intro.value - i * 0.08) / 0.6).clamp(0.0, 1.0));
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
                  );
                },
                child: ExampleCard(idea: exampleIdeas[i], onTap: () => widget.onSelected(exampleIdeas[i].prompt)),
              ),
            ),
        ],
      );
    });
  }
}

class ExampleCard extends StatelessWidget {
  const ExampleCard({super.key, required this.idea, required this.onTap});

  final ExampleIdea idea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: idea.prompt,
      excludeSemantics: true,
      child: Glass(
        padding: EdgeInsets.zero,
        radius: 22,
        tint: idea.accent,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            splashColor: idea.accent.withValues(alpha: 0.15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 92,
                  child: CustomPaint(painter: ExampleArtPainter(idea.art, idea.accent)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        idea.tag.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: idea.accent,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        idea.prompt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small decorative illustrations for the example cards. They carry no
/// data: shapes are symbolic, not to scale.
class ExampleArtPainter extends CustomPainter {
  ExampleArtPainter(this.art, this.accent);

  final ExampleArt art;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    switch (art) {
      case ExampleArt.moon:
        final earth = Offset(w * 0.26, h * 0.56);
        final moon = Offset(w * 0.8, h * 0.36);
        final dash = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1.4;
        for (var t = 0.0; t < 1; t += 0.08) {
          final a = Offset.lerp(earth, moon, t)!;
          final b = Offset.lerp(earth, moon, math.min(1, t + 0.04))!;
          canvas.drawLine(a, b, dash);
        }
        paintSphere(canvas, earth, h * 0.26, const Color(0xFF3B8BFF), highlight: Cosmos.cyan);
        paintSphere(canvas, moon, h * 0.1, const Color(0xFFB9C2DA));
      case ExampleArt.paper:
        const n = 7;
        final base = h * 0.86;
        final barW = w * 0.075;
        for (var i = 0; i < n; i++) {
          final bh = h * 0.045 * math.pow(1.5, i);
          final x = w * 0.12 + i * barW * 1.45;
          paintGlowBar(
            canvas,
            RRect.fromRectAndRadius(Rect.fromLTWH(x, base - bh, barW, bh), const Radius.circular(3)),
            Color.lerp(Cosmos.amber, Cosmos.coral, i / n)!,
          );
        }
        paintSphere(canvas, Offset(w * 0.86, h * 0.2), h * 0.09, const Color(0xFFB9C2DA));
      case ExampleArt.whale:
        final body = Path()
          ..moveTo(w * 0.1, h * 0.55)
          ..quadraticBezierTo(w * 0.22, h * 0.24, w * 0.52, h * 0.34)
          ..quadraticBezierTo(w * 0.66, h * 0.4, w * 0.74, h * 0.38)
          ..lineTo(w * 0.86, h * 0.22)
          ..lineTo(w * 0.83, h * 0.44)
          ..lineTo(w * 0.92, h * 0.58)
          ..lineTo(w * 0.74, h * 0.5)
          ..quadraticBezierTo(w * 0.5, h * 0.7, w * 0.1, h * 0.55)
          ..close();
        canvas.drawPath(body, Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        canvas.drawPath(body, Paint()
          ..shader = LinearGradient(colors: [lighten(accent, 0.1), darken(accent, 0.25)])
              .createShader(Offset.zero & size));
        final bus = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.36, h * 0.7, w * 0.24, h * 0.17), const Radius.circular(4));
        paintGlowBar(canvas, bus, Cosmos.amber);
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(
            Rect.fromLTWH(w * 0.38 + i * w * 0.05, h * 0.73, w * 0.035, h * 0.05),
            Paint()..color = Cosmos.void1.withValues(alpha: 0.7),
          );
        }
      case ExampleArt.planets:
        final sizes = [0.07, 0.11, 0.2, 0.15, 0.09];
        final colors = [Cosmos.coral, Cosmos.amber, Cosmos.violet, Cosmos.cyan, Cosmos.pink];
        var x = w * 0.1;
        for (var i = 0; i < sizes.length; i++) {
          final r = h * sizes[i] * 1.2;
          x += r;
          paintSphere(canvas, Offset(x, h * 0.58), r, colors[i]);
          x += r + w * 0.025;
        }
      case ExampleArt.rocket:
        final y = h * 0.72;
        paintGlowLine(canvas, Offset(w * 0.08, y), Offset(w * 0.92, y), accent, width: 1.6);
        for (var i = 0; i < 4; i++) {
          paintComet(canvas, Offset(w * (0.16 + i * 0.22), y), Color.lerp(Cosmos.cyan, Cosmos.pink, i / 3)!, radius: 3.5);
        }
        canvas.save();
        canvas.translate(w * 0.72, h * 0.34);
        canvas.rotate(math.pi / 4);
        final rocket = Path()
          ..moveTo(0, -h * 0.2)
          ..quadraticBezierTo(h * 0.08, -h * 0.05, h * 0.06, h * 0.1)
          ..lineTo(-h * 0.06, h * 0.1)
          ..quadraticBezierTo(-h * 0.08, -h * 0.05, 0, -h * 0.2)
          ..close();
        canvas.drawPath(rocket, Paint()..color = Colors.white.withValues(alpha: 0.92));
        canvas.drawCircle(Offset(0, -h * 0.05), h * 0.025, Paint()..color = accent);
        canvas.drawPath(
          Path()
            ..moveTo(-h * 0.045, h * 0.11)
            ..lineTo(0, h * 0.24)
            ..lineTo(h * 0.045, h * 0.11)
            ..close(),
          Paint()
            ..color = Cosmos.amber
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        canvas.restore();
      case ExampleArt.water:
        final c = Offset(w * 0.5, h * 0.52);
        final r = h * 0.34;
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(colors: [accent, Cosmos.cyan, accent.withValues(alpha: 0.2), accent])
              .createShader(Rect.fromCircle(center: c, radius: r));
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi * 1.7, false, ring);
        for (var i = 0; i < 4; i++) {
          final a = -math.pi / 2 + i * math.pi / 2;
          paintSphere(canvas, c + Offset(math.cos(a), math.sin(a)) * r, 5, Color.lerp(Cosmos.cyan, accent, i / 3)!);
        }
        final drop = Path()
          ..moveTo(c.dx, c.dy - 12)
          ..quadraticBezierTo(c.dx + 10, c.dy + 2, c.dx, c.dy + 8)
          ..quadraticBezierTo(c.dx - 10, c.dy + 2, c.dx, c.dy - 12)
          ..close();
        canvas.drawPath(drop, Paint()..color = Cosmos.cyan);
    }
  }

  @override
  bool shouldRepaint(ExampleArtPainter old) => old.art != art || old.accent != accent;
}
