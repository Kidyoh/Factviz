import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../templates/common/motion.dart';

/// The question field: frosted glass with an aurora border that comes alive
/// while focused.
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.controller, required this.onSubmit, this.focusNode});

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSubmit;

  static const int maxLength = 300;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> with SingleTickerProviderStateMixin {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus && ambientMotionOf(context)) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _submit() {
    final q = widget.controller.text.trim();
    if (q.length >= 3) widget.onSubmit(q);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) => CustomPaint(
        painter: _AuroraBorderPainter(rotation: _spin.value, active: focused),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final ready = value.text.trim().length >= 3;
            return TextField(
              controller: widget.controller,
              focusNode: _focus,
              maxLength: SearchBox.maxLength,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Cosmos.text),
              decoration: InputDecoration(
                hintText: 'Ask anything… how big is the Sun?',
                hintStyle: const TextStyle(color: Cosmos.textFaint, fontWeight: FontWeight.w400),
                counterText: '',
                filled: true,
                fillColor: const Color(0xE60A1028),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
                prefixIcon: const Icon(Icons.auto_awesome_rounded, color: Cosmos.cyan),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AnimatedOpacity(
                    opacity: ready ? 1 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Cosmos.cyan, Cosmos.violet]),
                        boxShadow: ready
                            ? [BoxShadow(color: Cosmos.cyan.withValues(alpha: 0.45), blurRadius: 16)]
                            : null,
                      ),
                      child: IconButton(
                        tooltip: 'Explain it',
                        onPressed: ready ? _submit : null,
                        icon: const Icon(Icons.arrow_upward_rounded, color: Cosmos.void0),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuroraBorderPainter extends CustomPainter {
  _AuroraBorderPainter({required this.rotation, required this.active});

  final double rotation;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.75), const Radius.circular(29));
    final shader = SweepGradient(
      transform: GradientRotation(rotation * 2 * math.pi),
      colors: active
          ? const [Cosmos.cyan, Cosmos.violet, Cosmos.pink, Cosmos.cyan]
          : const [Color(0x405CE1FF), Color(0x309C8CFF), Color(0x20FF7AC6), Color(0x405CE1FF)],
    ).createShader(rect);
    if (active) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_AuroraBorderPainter old) => old.rotation != rotation || old.active != active;
}
