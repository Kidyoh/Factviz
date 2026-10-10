import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/theme.dart';

class ExampleIdea {
  const ExampleIdea(this.prompt, this.tag);

  final String prompt;
  final String tag;
}

/// Example questions, at least one per template.
const exampleIdeas = [
  ExampleIdea('How far is the Moon?', 'Distance'),
  ExampleIdea('Fold a paper 42 times to reach the Moon', 'Growth'),
  ExampleIdea('Blue whale vs a school bus', 'Comparison'),
  ExampleIdea('Sizes of the planets', 'To scale'),
  ExampleIdea('History of human spaceflight', 'Timeline'),
  ExampleIdea('How the water cycle works', 'Process'),
];

final examplePrompts = [for (final e in exampleIdeas) e.prompt];

/// A numbered index of example questions, like a newspaper's contents.
class ExamplePrompts extends StatelessWidget {
  const ExamplePrompts({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        for (var i = 0; i < exampleIdeas.length; i++)
          ExampleRow(index: i + 1, idea: exampleIdeas[i], onTap: () => onSelected(exampleIdeas[i].prompt))
              .animate(target: reduce ? 1 : null)
              .fadeIn(delay: (80 * i).ms, duration: 380.ms)
              .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class ExampleRow extends StatelessWidget {
  const ExampleRow({super.key, required this.index, required this.idea, required this.onTap});

  final int index;
  final ExampleIdea idea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: idea.prompt,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Palette.rule2,
        highlightColor: Palette.rule2,
        child: Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.rule))),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: const TextStyle(fontFamily: serif, fontSize: 15, color: Palette.ink3, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(idea.tag.toUpperCase(), style: Txt.kicker.copyWith(fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(idea.prompt, style: const TextStyle(fontFamily: serif, fontSize: 18, height: 1.3, color: Palette.ink)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 14, left: 8),
                child: Icon(Icons.arrow_forward, size: 18, color: Palette.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
