import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws player tokens: a coloured disc with a symbol, so players can be
/// told apart by shape as well as by colour.
class TokenArt {
  TokenArt._();

  static final List<Path> _symbols = List.generate(10, _buildSymbol);

  /// Symbols that are strokes rather than fills.
  static const _stroked = {0, 1, 6};

  static void paint(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    int token, {
    required Color symbolColor,
    double rotation = 0,
    double opacity = 1,
    bool outline = false,
  }) {
    if (radius <= 0.5 || opacity <= 0) return;
    final a = opacity.clamp(0.0, 1.0);
    canvas.drawCircle(center, radius, Paint()..color = color.withValues(alpha: a));
    if (outline) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, radius * 0.06)
          ..color = Colors.black.withValues(alpha: 0.25 * a),
      );
    }
    final i = token % _symbols.length;
    final s = radius * 0.5;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.scale(s);
    final paint = Paint()
      ..color = symbolColor.withValues(alpha: 0.88 * a)
      ..isAntiAlias = true;
    if (_stroked.contains(i)) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(_symbols[i], paint);
    canvas.restore();
  }

  static Path _buildSymbol(int i) {
    final p = Path();
    switch (i) {
      case 0: // Classic: X
        p
          ..moveTo(-0.62, -0.62)
          ..lineTo(0.62, 0.62)
          ..moveTo(0.62, -0.62)
          ..lineTo(-0.62, 0.62);
      case 1: // Circle: ring
        p.addOval(Rect.fromCircle(center: Offset.zero, radius: 0.7));
      case 2: // Star
        for (var k = 0; k < 10; k++) {
          final r = k.isEven ? 1.0 : 0.45;
          final a = -math.pi / 2 + k * math.pi / 5;
          final o = Offset(math.cos(a) * r, math.sin(a) * r + 0.05);
          k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        p.close();
      case 3: // Diamond
        p
          ..moveTo(0, -0.95)
          ..lineTo(0.68, 0)
          ..lineTo(0, 0.95)
          ..lineTo(-0.68, 0)
          ..close();
      case 4: // Triangle
        p
          ..moveTo(0, -0.85)
          ..lineTo(0.85, 0.65)
          ..lineTo(-0.85, 0.65)
          ..close();
      case 5: // Heart
        p
          ..moveTo(0, 0.85)
          ..cubicTo(-1.25, 0.0, -0.75, -1.05, 0, -0.42)
          ..cubicTo(0.75, -1.05, 1.25, 0.0, 0, 0.85)
          ..close();
      case 6: // Cross: plus
        p
          ..moveTo(0, -0.8)
          ..lineTo(0, 0.8)
          ..moveTo(-0.8, 0)
          ..lineTo(0.8, 0);
      case 7: // Hex
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3;
          final o = Offset(math.cos(a) * 0.85, math.sin(a) * 0.85);
          k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        p.close();
      case 8: // Crown
        p
          ..moveTo(-0.9, 0.6)
          ..lineTo(-0.9, -0.55)
          ..lineTo(-0.45, -0.05)
          ..lineTo(0, -0.8)
          ..lineTo(0.45, -0.05)
          ..lineTo(0.9, -0.55)
          ..lineTo(0.9, 0.6)
          ..close();
      default: // Lightning
        p
          ..moveTo(0.2, -1.0)
          ..lineTo(-0.6, 0.12)
          ..lineTo(-0.05, 0.12)
          ..lineTo(-0.25, 1.0)
          ..lineTo(0.6, -0.15)
          ..lineTo(0.05, -0.15)
          ..close();
    }
    return p;
  }
}

/// A single token as a widget (score chips, token collection, menus).
class TokenIcon extends StatelessWidget {
  const TokenIcon({
    super.key,
    required this.color,
    required this.token,
    required this.symbolColor,
    this.size = 24,
    this.dimmed = false,
  });

  final Color color;
  final int token;
  final Color symbolColor;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _TokenIconPainter(color, token, symbolColor, dimmed ? 0.35 : 1),
    ),
  );
}

class _TokenIconPainter extends CustomPainter {
  _TokenIconPainter(this.color, this.token, this.symbolColor, this.opacity);
  final Color color;
  final int token;
  final Color symbolColor;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) => TokenArt.paint(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2,
    color,
    token,
    symbolColor: symbolColor,
    opacity: opacity,
  );

  @override
  bool shouldRepaint(_TokenIconPainter old) =>
      old.color != color || old.token != token || old.symbolColor != symbolColor || old.opacity != opacity;
}
