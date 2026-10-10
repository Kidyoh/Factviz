import 'package:flutter/material.dart';

/// The single question field on the home screen.
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
        return TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxLength,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Ask anything, e.g. how big is the Sun?',
            counterText: '',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton.filled(
                tooltip: 'Explain it',
                onPressed: ready ? _submit : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        );
      },
    );
  }
}
