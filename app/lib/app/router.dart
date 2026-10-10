import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../screens/dev_gallery_screen.dart';
import '../screens/home_screen.dart';
import '../screens/result_screen.dart';
import '../state/visualize_controller.dart';

/// The template gallery: always in debug builds, and in other builds made
/// with `--dart-define=SHOW_GALLERY=true` (for previewing without a server).
const bool showGallery = kDebugMode || bool.fromEnvironment('SHOW_GALLERY');

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) {
        // Share links arrive as factviz://app/v/<payload>.
        if (state.uri.scheme == ShareCodec.scheme) {
          final payload = ShareCodec.payloadFromUri(state.uri);
          return payload == null ? '/' : '${ShareCodec.routePrefix}$payload';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => HomeScreen(initialQuery: state.uri.queryParameters['q']),
        ),
        GoRoute(
          path: '/explain',
          redirect: (context, state) => (state.uri.queryParameters['q']?.trim() ?? '').isEmpty ? '/' : null,
          builder: (context, state) => ResultScreen(request: QueryRequest(state.uri.queryParameters['q']!.trim())),
        ),
        GoRoute(
          path: '/v/:payload',
          builder: (context, state) => ResultScreen(request: SharedRequest(state.pathParameters['payload']!)),
        ),
        if (showGallery) ...[
          GoRoute(path: '/dev', builder: (context, state) => const DevGalleryScreen()),
          GoRoute(
            path: '/dev/:index',
            builder: (context, state) => DevPreviewScreen(index: int.tryParse(state.pathParameters['index']!) ?? 0),
          ),
        ],
      ],
    );
