import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Small caps label above a headline, e.g. "TO SCALE".
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = Palette.accent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Txt.kicker.copyWith(color: color));
}

/// A section heading with a hairline rule, newspaper style.
class SectionRule extends StatelessWidget {
  const SectionRule(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 2, color: Palette.ink),
        const SizedBox(height: 8),
        Text(title.toUpperCase(), style: Txt.kicker.copyWith(color: Palette.ink, letterSpacing: 1.6)),
      ],
    );
  }
}
