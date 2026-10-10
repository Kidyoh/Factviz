import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Fixed-window, per-client-IP rate limit for `/api/*` routes.
///
/// In-memory, so it is per server instance; enough to stop a single client
/// from running up LLM costs.
Middleware rateLimit({
  required int perMinute,
  bool trustProxy = false,
  DateTime Function() now = DateTime.now,
}) {
  final windows = <String, (int minute, int count)>{};
  return (inner) => (request) {
        if (perMinute <= 0 || !request.url.path.startsWith('api/')) return inner(request);
        final ip = _clientIp(request, trustProxy);
        final minute = now().millisecondsSinceEpoch ~/ 60000;
        final (lastMinute, count) = windows[ip] ?? (minute, 0);
        final next = lastMinute == minute ? count + 1 : 1;
        if (windows.length > 10000) windows.removeWhere((_, w) => w.$1 != minute);
        windows[ip] = (minute, next);
        if (next > perMinute) {
          return Response(
            429,
            body: jsonEncode({
              'error': {'code': 'rate_limited', 'message': 'Too many requests. Please wait a minute and try again.'},
            }),
            headers: {'content-type': 'application/json; charset=utf-8', 'retry-after': '60'},
          );
        }
        return inner(request);
      };
}

String _clientIp(Request request, bool trustProxy) {
  if (trustProxy) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) return forwarded.split(',').first.trim();
  }
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}
