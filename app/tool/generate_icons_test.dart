// Generates the launcher icon and splash images from OrbitMarkPainter.
//
//   cd app && flutter test tool/generate_icons_test.dart
//
// Writes PNGs into android/app/src/main/res. Not part of the normal test run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:factviz/ui/cosmic/orbit_mark.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

/// Renders the mark into a [px]×[px] PNG. [markScale] is the mark's share of
/// the canvas; [background] paints the deep-space backdrop.
Future<void> _render(String path, int px, {required double markScale, required bool background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final size = ui.Size.square(px.toDouble());
  final painter = OrbitMarkPainter(const AlwaysStoppedAnimation(0.18), background: background);
  if (background) {
    // Backdrop fills the canvas; the mark is painted again, scaled, on top.
    OrbitMarkPainter(const AlwaysStoppedAnimation(0.18), background: true, markVisible: false).paint(canvas, size);
  }
  final markSize = px * markScale;
  canvas.save();
  canvas.translate((px - markSize) / 2, (px - markSize) / 2);
  OrbitMarkPainter(painter.t).paint(canvas, ui.Size.square(markSize));
  canvas.restore();
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate launcher icons and splash', () async {
    for (final MapEntry(key: dpi, value: scale) in _densities.entries) {
      // Legacy square icon (48dp).
      await _render('$_res/mipmap-$dpi/ic_launcher.png', (48 * scale).round(), markScale: 0.82, background: true);
      // Adaptive icon foreground (108dp canvas, 66dp safe zone).
      await _render('$_res/mipmap-$dpi/ic_launcher_foreground.png', (108 * scale).round(),
          markScale: 0.56, background: false);
      // Splash mark for pre-Android 12 launch screens (120dp).
      await _render('$_res/drawable-$dpi/splash_mark.png', (120 * scale).round(), markScale: 1, background: false);
    }
    // Store listing / README icon.
    await _render('assets/icon/icon_1024.png', 1024, markScale: 0.82, background: true);
  });
}
