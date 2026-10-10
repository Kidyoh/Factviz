import 'package:flutter/painting.dart';

/// Lays out a single line of text for drawing on a canvas.
TextPainter layoutText(
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.left,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
}
