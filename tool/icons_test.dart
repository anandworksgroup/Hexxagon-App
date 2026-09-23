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

/// A flat-top hexagon with softened corners, centred on the origin.
Path _hex(double r, {double corner = 0}) {
  final points = [
    for (var k = 0; k < 6; k++)
      Offset(math.cos(k * math.pi / 3) * r, math.sin(k * math.pi / 3) * r),
  ];
  final path = Path();
  if (corner <= 0) {
    for (var i = 0; i < 6; i++) {
      i == 0 ? path.moveTo(points[i].dx, points[i].dy) : path.lineTo(points[i].dx, points[i].dy);
    }
    return path..close();
  }
  // Cut each corner back along both edges and round it with a quadratic.
  for (var i = 0; i < 6; i++) {
    final prev = points[(i + 5) % 6];
    final cur = points[i];
    final next = points[(i + 1) % 6];
    final into = cur + (prev - cur) / (prev - cur).distance * corner;
    final out = cur + (next - cur) / (next - cur).distance * corner;
    i == 0 ? path.moveTo(into.dx, into.dy) : path.lineTo(into.dx, into.dy);
    path.quadraticBezierTo(cur.dx, cur.dy, out.dx, out.dy);
  }
  return path..close();
}

/// The icon: one bold hexagon token carrying the game's X symbol, with a
/// captured opponent token tucked behind it. Kept to a few big shapes so it
/// still reads at 48 px in a launcher.
///
/// [inset] is the fraction of the canvas the artwork may use (adaptive icons
/// need to stay inside the central safe zone).
Future<List<int>> _render(int px, {required bool background, double inset = 0.8}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = px.toDouble();
  final c = Offset(size / 2, size / 2);
  if (background) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = _bg);
    // A soft lift behind the badge so the dark square isn't completely flat.
    canvas.drawCircle(
      c,
      size * 0.46,
      Paint()
        ..shader = ui.Gradient.radial(c, size * 0.46, [
          const Color(0xFF262626),
          _bg,
        ], [0.0, 1.0]),
    );
  }

  final r = size * inset * 0.5;
  canvas.save();
  canvas.translate(c.dx, c.dy);

  // Board hexes peeking out behind, hinting at the grid.
  for (final dir in [0, 2, 4]) {
    final a = dir * math.pi / 3 + math.pi / 6;
    final o = Offset(math.cos(a), math.sin(a)) * r * 0.80;
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.drawPath(_hex(r * 0.28, corner: r * 0.05), Paint()..color = _cell);
    canvas.drawPath(
      _hex(r * 0.28, corner: r * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.018)
        ..color = _edge,
    );
    canvas.restore();
  }

  // The opponent token being converted, half hidden behind the badge.
  final opp = Offset(r * 0.62, r * 0.50);
  TokenArt.paint(canvas, opp, r * 0.30, _purple, 2, symbolColor: _bg);

  // The badge itself.
  final badge = _hex(r * 0.78, corner: r * 0.16);
  canvas.drawPath(
    badge,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(-r * 0.6, -r * 0.7),
        Offset(r * 0.6, r * 0.8),
        [const Color(0xFFFFDC6B), const Color(0xFFEFA227)],
      ),
  );

  // The X, drawn thick enough to survive the smallest launcher size.
  final arm = r * 0.3;
  canvas.drawPath(
    Path()
      ..moveTo(-arm, -arm)
      ..lineTo(arm, arm)
      ..moveTo(arm, -arm)
      ..lineTo(-arm, arm),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.17
      ..strokeCap = StrokeCap.round
      ..color = _bg,
  );
  canvas.restore();

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
