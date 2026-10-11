import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../data/library_repository.dart';
import '../state/library.dart';
import '../ui/editorial.dart';
import '../ui/template_labels.dart';

/// Browse and search the bundled, ready-made visualizations.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();
  late String? _category = widget.initialCategory;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(LibraryCategory c, LibraryEntry e) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final v = e.visualization;
    return [e.query, e.title, v.facts.topic, c.title, templateLabel(e.template)].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => context.pop())
            : IconButton(icon: const Icon(Icons.home_outlined), tooltip: 'Home', onPressed: () => context.go('/')),
        title: const Text('Library'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: SafeArea(
        top: false,
        child: switch (library) {
          AsyncData(:final value) => _content(value),
          AsyncError() => const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text("The library couldn't be loaded.", style: Txt.dek, textAlign: TextAlign.center),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator(color: Palette.ink, strokeWidth: 2)),
        },
      ),
    );
  }

  Widget _content(List<LibraryCategory> categories) {
    final total = categories.entries.length;
    final shown = [
      for (final c in categories)
        if (_category == null || c.id == _category) (c, [for (final e in c.entries) if (_matches(c, e)) e]),
    ].where((s) => s.$2.isNotEmpty).toList();
    final rows = <Widget>[
      const Kicker('The library'),
      const SizedBox(height: 6),
      Semantics(
        header: true,
        child: Text('$total visualizations, ready to explore', style: Txt.headline),
      ),
      const SizedBox(height: 8),
      const Text('Real figures, each with its source. Opens instantly, no key needed.', style: Txt.dek),
      const SizedBox(height: 20),
      TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v.trim()),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontFamily: serif, fontSize: 17, color: Palette.ink),
        decoration: InputDecoration(
          hintText: 'Search the library',
          hintStyle: const TextStyle(fontFamily: serif, fontSize: 17, color: Palette.ink3),
          prefixIcon: const Icon(Icons.search, color: Palette.ink2),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
          filled: true,
          fillColor: Palette.paperDeep,
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _Chip(label: 'All', selected: _category == null, onTap: () => setState(() => _category = null)),
            for (final c in categories)
              _Chip(
                label: c.title,
                selected: _category == c.id,
                onTap: () => setState(() => _category = _category == c.id ? null : c.id),
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      if (shown.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('Nothing matches that search.', style: Txt.dek, textAlign: TextAlign.center),
        ),
      for (final (c, entries) in shown) ...[
        SectionRule('${c.title} · ${entries.length}'),
        const SizedBox(height: 2),
        for (final e in entries) _EntryRow(entry: e, onTap: () => context.push('/library/${c.id}/${e.id}')),
        const SizedBox(height: 28),
      ],
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: rows.length,
          itemBuilder: (context, i) => rows[i],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: selected ? Palette.ink : Colors.transparent,
              shape: const StadiumBorder(side: BorderSide(color: Palette.ink)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: sans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Palette.paper : Palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${entry.query}. ${templateLabel(entry.template)}.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Palette.rule2,
        highlightColor: Palette.rule2,
        child: Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.rule))),
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(templateLabel(entry.template).toUpperCase(), style: Txt.kicker.copyWith(fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(entry.query, style: const TextStyle(fontFamily: serif, fontSize: 17.5, height: 1.3, color: Palette.ink)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 18, color: Palette.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
