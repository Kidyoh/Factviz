import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../screens/dev_gallery_screen.dart';
import '../screens/home_screen.dart';

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        if (kDebugMode) ...[
          GoRoute(path: '/dev', builder: (context, state) => const DevGalleryScreen()),
          GoRoute(
            path: '/dev/:index',
            builder: (context, state) => DevPreviewScreen(index: int.tryParse(state.pathParameters['index']!) ?? 0),
          ),
        ],
      ],
    );
