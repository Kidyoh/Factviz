import 'dart:io';

import 'package:factviz_server/factviz_server.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final ServerConfig config;
  try {
    config = ServerConfig.fromEnvironment(Platform.environment);
  } on ConfigException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }
  final server = await io.serve(buildHandler(config), InternetAddress.anyIPv4, config.port);
  server.autoCompress = true;
  stdout.writeln('Explain It Visually API on :${server.port} '
      '(provider=${config.provider}, facts=${config.factsModelOrDefault}, planner=${config.plannerModelOrDefault})');

  // Graceful shutdown for container platforms.
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      await server.close();
      exit(0);
    });
  }
}
