import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'canvas_text.dart';

/// Painting helpers for the cinematic template look: lit spheres, glowing
/// strokes and bars, and label pills.

Color lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color darken(Color c, double amount) => lighten(c, -amount);

/// A sphere lit from the top-left, with an atmospheric glow.
void paintSphere(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double opacity = 1,
  Color? highlight,
  bool glow = true,
}) {
  if (radius <= 0 || opacity <= 0) return;
  if (glow && radius > 1.5) {
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()
        ..color = color.withValues(alpha: 0.35 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2, radius * 0.45)),
    );
  }
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        radius: 1.05,
        colors: [
          lighten(highlight ?? color, 0.28).withValues(alpha: opacity),
          color.withValues(alpha: opacity),
          darken(color, 0.38).withValues(alpha: opacity),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(rect),
  );
  if (radius > 6) {
    // Thin rim light on the lit side.
    canvas.drawArc(
      rect.deflate(0.6),
      math.pi * 1.05,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.min(2, radius * 0.05)
        ..color = Colors.white.withValues(alpha: 0.28 * opacity),
    );
  }
}

/// A rounded bar with a vertical sheen, top highlight and glow.
void paintGlowBar(Canvas canvas, RRect rrect, Color color, {double opacity = 1, bool vertical = false}) {
  if (opacity <= 0 || rrect.width <= 0 || rrect.height <= 0) return;
  canvas.drawRRect(
    rrect.inflate(1),
    Paint()
      ..color = color.withValues(alpha: 0.35 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  final rect = rrect.outerRect;
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = LinearGradient(
        begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
        end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
        colors: [
          lighten(color, 0.15).withValues(alpha: opacity),
          color.withValues(alpha: opacity),
          darken(color, 0.22).withValues(alpha: opacity),
        ],
      ).createShader(rect),
  );
  final hl = vertical
      ? Rect.fromLTWH(rect.left + 2, rect.top + 2, math.max(0, rect.width * 0.25), math.max(0, rect.height - 4))
      : Rect.fromLTWH(rect.left + 2, rect.top + 1.5, math.max(0, rect.width - 4), math.max(0, rect.height * 0.3));
  canvas.drawRRect(
    RRect.fromRectAndRadius(hl, Radius.circular(math.min(rrect.tlRadiusX, hl.shortestSide / 2))),
    Paint()..color = Colors.white.withValues(alpha: 0.18 * opacity),
  );
}

/// A line with a soft glow underneath.
void paintGlowLine(Canvas canvas, Offset a, Offset b, Color color, {double width = 2, double opacity = 1}) {
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = color.withValues(alpha: 0.45 * opacity)
      ..strokeWidth = width * 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2),
  );
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

/// A glowing dot with a bright core, e.g. the head of a growing line.
void paintComet(Canvas canvas, Offset head, Color color, {double radius = 5, double opacity = 1}) {
  canvas.drawCircle(
    head,
    radius * 3,
    Paint()
      ..color = color.withValues(alpha: 0.35 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.6),
  );
  canvas.drawCircle(head, radius, Paint()..color = color.withValues(alpha: opacity));
  canvas.drawCircle(head, radius * 0.45, Paint()..color = Colors.white.withValues(alpha: 0.9 * opacity));
}

/// Draws [painter] text on a dark translucent pill centred at [center].
Rect paintPill(
  Canvas canvas,
  TextPainter painter,
  Offset center, {
  Color background = const Color(0xB3080C1E),
  Color? border,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
}) {
  final rect = Rect.fromCenter(
    center: center,
    width: painter.width + padding.horizontal,
    height: painter.height + padding.vertical,
  );
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
  canvas.drawRRect(rrect, Paint()..color = background);
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = border ?? Colors.white.withValues(alpha: 0.14),
  );
  painter.paint(canvas, Offset(rect.left + padding.left, rect.top + padding.top));
  return rect;
}

/// Radial burst of sparks for celebratory moments. [t] runs 0..1.
void paintBurst(Canvas canvas, Offset origin, double t, List<Color> colors, {int sparks = 28, double reach = 90}) {
  if (t <= 0 || t >= 1) return;
  final ease = Curves.easeOutCubic.transform(t);
  final fade = 1 - Curves.easeIn.transform(t);
  for (var i = 0; i < sparks; i++) {
    final a = i / sparks * 2 * math.pi + (i.isEven ? 0.08 : -0.05);
    final dist = reach * ease * (0.55 + 0.45 * ((i * 37) % 11) / 10);
    final p = origin + Offset(math.cos(a), math.sin(a)) * dist;
    final color = colors[i % colors.length].withValues(alpha: fade);
    canvas.drawCircle(p, 2.2 * fade + 0.6, Paint()..color = color);
    canvas.drawLine(
      origin + Offset(math.cos(a), math.sin(a)) * dist * 0.75,
      p,
      Paint()
        ..color = color.withValues(alpha: fade * 0.5)
        ..strokeWidth = 1.2,
    );
  }
}

/// A two-line name/value label on a dark pill, measured before painting so
/// callers can avoid overlaps.
class PillLabel {
  PillLabel(String name, String value, TextStyle base, {required this.accent, double scale = 1, double maxWidth = 170})
      : _name = layoutText(
          name,
          base.copyWith(fontSize: 12.5 * scale, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
          maxWidth: maxWidth,
        ),
        _value = layoutText(
          value,
          base.copyWith(fontSize: 11 * scale, fontWeight: FontWeight.w600, color: accent, height: 1.2),
          maxWidth: maxWidth,
        );

  final Color accent;
  final TextPainter _name, _value;

  static const double _padX = 9, _padY = 5;

  Size get size => Size(math.max(_name.width, _value.width) + 2 * _padX, _name.height + _value.height + 2 * _padY);

  void paint(Canvas canvas, Offset topLeft, {double opacity = 1}) {
    final rect = topLeft & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF080C1E).withValues(alpha: 0.78 * opacity));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = accent.withValues(alpha: 0.5 * opacity),
    );
    canvas.saveLayer(rect.inflate(2), Paint()..color = Colors.white.withValues(alpha: opacity));
    _name.paint(canvas, Offset(rect.left + (rect.width - _name.width) / 2, rect.top + _padY));
    _value.paint(canvas, Offset(rect.left + (rect.width - _value.width) / 2, rect.top + _padY + _name.height));
    canvas.restore();
  }
}
