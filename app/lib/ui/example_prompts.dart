import 'package:flutter/material.dart';

/// Example questions, one or more per template.
const examplePrompts = [
  'How far is the Moon?',
  'Fold a paper 42 times to reach the Moon',
  'Blue whale vs a school bus',
  'Sizes of the planets',
  'History of human spaceflight',
  'How the water cycle works',
];

class ExamplePrompts extends StatelessWidget {
  const ExamplePrompts({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final prompt in examplePrompts)
          ActionChip(
            label: Text(prompt),
            onPressed: () => onSelected(prompt),
          ),
      ],
    );
  }
}
