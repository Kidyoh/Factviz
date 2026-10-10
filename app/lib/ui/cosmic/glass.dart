import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Frosted-glass surface with a light-catching gradient border.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.blur = false,
    this.tint,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Blurs what is behind. Costly; use for a few prominent surfaces only.
  final bool blur;

  /// Optional colour wash over the glass.
  final Color? tint;

  /// Optional coloured outer glow.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget body = CustomPaint(
      foregroundPainter: GradientBorderPainter(radius: radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Untinted glass leans cool (violet → cyan) so it never reads grey.
            colors: tint == null
                ? const [Color(0x1F8C86FF), Color(0x0A5CE1FF)]
                : [tint!.withValues(alpha: 0.14), tint!.withValues(alpha: 0.04)],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (blur) {
      body = BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: body);
    }
    body = ClipRRect(borderRadius: shape, child: body);
    if (glow != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [BoxShadow(color: glow!.withValues(alpha: 0.25), blurRadius: 32, spreadRadius: -6)],
        ),
        child: body,
      );
    }
    return body;
  }
}

/// Strokes a rounded rect with a bright-top-left to faint-bottom-right edge.
class GradientBorderPainter extends CustomPainter {
  const GradientBorderPainter({
    required this.radius,
    this.colors = const [Color(0x47FFFFFF), Color(0x0DFFFFFF), Color(0x1FFFFFFF)],
    this.width = 1,
  });

  final double radius;
  final List<Color> colors;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GradientBorderPainter old) => old.radius != radius || old.colors != colors;
}

/// Text filled with the aurora gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.gradient = Cosmos.aurora, this.textAlign});

  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

/// Round glass icon button used on top of the cosmic background.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Cosmos.glassFill,
        shape: const CircleBorder(side: BorderSide(color: Cosmos.glassBorder)),
        clipBehavior: Clip.antiAlias,
        child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, size: 20)),
      ),
    );
  }
}
