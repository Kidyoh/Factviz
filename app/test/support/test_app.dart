import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:factviz/app/theme.dart';

/// Wraps [child] in a themed app at a phone-sized viewport.
Future<void> pumpPhone(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: 3, disableAnimations: reduceMotion),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Advances time in steps without waiting for animations to settle, since
/// autoplaying templates never settle.
Future<void> advance(WidgetTester tester, Duration total, {int steps = 20}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(total ~/ steps);
  }
}
