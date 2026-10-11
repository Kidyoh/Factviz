import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';

/// The bundled library, loaded once.
final libraryProvider = FutureProvider<List<LibraryCategory>>((ref) => LibraryRepository(rootBundle).load());
