// Renders the app icon for Android and iOS from the game's own token art.
// Runs as a test because it needs the Flutter engine to rasterise:
//
//   flutter test tool/icons_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexadominate/ui/widgets/token_painter.dart';

const _bg = Color(0xFF151515);
const _cell = Color(0xFF303030);
const _edge = Color(0xFF3B3B3B);
const _yellow = Color(0xFFF7C948);
const _purple = Color(0xFFA880F5);

/// [inset] is the fraction of the canvas the artwork may use (adaptive icons
/// need to stay inside the central safe zone).
Future<List<int>> _render(int px, {required bool background, double inset = 0.8}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = px.toDouble();
  if (background) canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = _bg);
  final s = size * inset / 5.2;
  final c = Offset(size / 2, size / 2);
  const cells = [(0, 0), (1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];
  const owners = [0, 0, 1, -1, 0, -1, 0];
  for (var i = 0; i < cells.length; i++) {
    final (q, r) = cells[i];
    final center = c + Offset(1.5 * q * s, math.sqrt(3) * (r + q / 2) * s);
    final path = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3;
      final o = center + Offset(math.cos(a), math.sin(a)) * s * 0.92;
      k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _cell);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.05)
        ..color = _edge,
    );
    final o = owners[i];
    if (o >= 0) {
      TokenArt.paint(
        canvas,
        center,
        s * 0.62,
        o == 0 ? _yellow : _purple,
        o == 0 ? 0 : 2,
        symbolColor: _bg,
      );
    }
  }
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<void> _write(String path, int px, {bool background = true, double inset = 0.8}) async {
  final bytes = await _render(px, background: background, inset: inset);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

void main() {
  test('render icons', () async {
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      const android = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
      for (final e in android.entries) {
        final dir = 'android/app/src/main/res/mipmap-${e.key}';
        await _write('$dir/ic_launcher.png', (48 * e.value).round(), inset: 0.86);
        // Adaptive icon foreground: 108dp canvas, art inside the 66dp safe zone.
        await _write(
          '$dir/ic_launcher_foreground.png',
          (108 * e.value).round(),
          background: false,
          inset: 0.52,
        );
      }
      File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background"/>\n'
          '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
          '</adaptive-icon>\n',
        );

      const ios = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final e in ios.entries) {
        await _write('ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}', e.value);
      }
    });
  });
}
