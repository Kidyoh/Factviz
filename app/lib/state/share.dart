import 'package:factviz_core/factviz_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet. Overridable in tests.
typedef ShareText = Future<void> Function(String text, {String? subject});

final shareTextProvider = Provider<ShareText>(
  (ref) => (text, {subject}) => SharePlus.instance.share(ShareParams(text: text, subject: subject)),
);

/// Text shared for a result: its title and a link that re-renders it from
/// the validated payload, with no LLM call.
String shareMessage(Visualization viz) => '${viz.props.title}\n${ShareCodec.link(viz)}';
