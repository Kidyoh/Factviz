import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The single question field: a serif line on paper, no chrome.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.controller, required this.onSubmit, this.focusNode});

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSubmit;

  static const int maxLength = 300;

  void _submit() {
    final q = controller.text.trim();
    if (q.length >= 3) onSubmit(q);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final ready = value.text.trim().length >= 3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: maxLength,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontFamily: serif, fontSize: 22, height: 1.3, color: Palette.ink),
                decoration: const InputDecoration(
                  hintText: 'How far away is the Moon?',
                  hintStyle: TextStyle(fontFamily: serif, fontSize: 22, fontStyle: FontStyle.italic, color: Palette.ink3),
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.5)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Palette.accent, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton.filled(
                tooltip: 'Explain it',
                onPressed: ready ? _submit : null,
                style: IconButton.styleFrom(
                  backgroundColor: Palette.ink,
                  foregroundColor: Palette.paper,
                  disabledBackgroundColor: Palette.rule,
                  disabledForegroundColor: Palette.paper,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}
