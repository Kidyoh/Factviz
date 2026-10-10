import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge paper, with dark system icons.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: FactvizApp()));
}

class FactvizApp extends StatefulWidget {
  const FactvizApp({super.key, this.initialLocation = '/'});

  /// Starting route; tests use it to open share links directly.
  final String initialLocation;

  @override
  State<FactvizApp> createState() => _FactvizAppState();
}

class _FactvizAppState extends State<FactvizApp> {
  late final _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Explain It Visually',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}
