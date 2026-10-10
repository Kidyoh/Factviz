// Generates the launcher icon and splash images from LogoPainter.
//
//   cd app && flutter test tool/generate_icons_test.dart
//
// Writes PNGs into android/app/src/main/res. Not part of the normal test run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:factviz/app/theme.dart';
import 'package:factviz/ui/logo_painter.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

/// Renders the mark into a [px]×[px] PNG, scaled to [markScale] of the canvas.
Future<void> _render(String path, int px, {required double markScale, required bool background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final size = ui.Size.square(px.toDouble());
  if (background) canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = Palette.paper);
  final mark = px * markScale;
  canvas.translate((px - mark) / 2, (px - mark) / 2);
  const LogoPainter().paint(canvas, ui.Size.square(mark));
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate launcher icons and splash', () async {
    for (final MapEntry(key: dpi, value: scale) in _densities.entries) {
      await _render('$_res/mipmap-$dpi/ic_launcher.png', (48 * scale).round(), markScale: 0.86, background: true);
      await _render('$_res/mipmap-$dpi/ic_launcher_foreground.png', (108 * scale).round(), markScale: 0.6, background: false);
      await _render('$_res/drawable-$dpi/splash_mark.png', (120 * scale).round(), markScale: 1, background: false);
    }
    await _render('assets/icon/icon_1024.png', 1024, markScale: 0.86, background: true);
  });
}
