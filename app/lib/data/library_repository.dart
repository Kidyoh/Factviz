import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads the bundled library from `assets/library/`. Every entry goes
/// through the same validation and resolution as a live answer; a category
/// file that fails is left out rather than shown with bad data.
class LibraryRepository {
  const LibraryRepository(this._bundle, {this.resolver = const PlanResolver()});

  static const root = 'assets/library';

  final AssetBundle _bundle;
  final PlanResolver resolver;

  Future<List<LibraryCategory>> load() async {
    final index = jsonDecode(await _bundle.loadString('$root/index.json')) as Map<String, dynamic>;
    final out = <LibraryCategory>[];
    for (final id in (index['categories'] as List).cast<String>()) {
      final json = jsonDecode(await _bundle.loadString('$root/$id.json'));
      switch (LibraryCategory.fromJson(json, resolver: resolver)) {
        case Valid(:final value):
          out.add(value);
        case Invalid(:final issues):
          debugPrint('Library category "$id" skipped: ${issues.take(5).join('; ')}');
      }
    }
    return out;
  }
}

/// All entries in library order.
extension LibraryEntries on List<LibraryCategory> {
  Iterable<LibraryEntry> get entries => expand((c) => c.entries);

  LibraryEntry? find(String category, String id) {
    for (final c in this) {
      if (c.id != category) continue;
      for (final e in c.entries) {
        if (e.id == id) return e;
      }
    }
    return null;
  }
}
