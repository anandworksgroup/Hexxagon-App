import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/settings.dart';
import '../../engine/board_layout.dart';
import '../../engine/game_engine.dart';
import '../../engine/game_state.dart';
import '../../engine/hex.dart';
import '../theme/app_theme.dart';
import 'token_painter.dart';

/// How one seat is drawn.
class PlayerLook {
  const PlayerLook({required this.color, required this.token, required this.name});
  final Color color;
  final int token;
  final String name;
}

/// Maps between board cells and pixels for a given widget size.
class BoardGeometry {
  BoardGeometry(this.layout, this.size, {double padding = 8, double maxCell = 72}) {
    const hh = 0.8660254037844386; // sqrt(3) / 2
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final h in layout.cells) {
      minX = math.min(minX, h.x - 1);
      maxX = math.max(maxX, h.x + 1);
      minY = math.min(minY, h.y - hh);
      maxY = math.max(maxY, h.y + hh);
    }
    final availW = math.max(1.0, size.width - padding * 2);
    final availH = math.max(1.0, size.height - padding * 2);
    scale = math.min(maxCell, math.min(availW / (maxX - minX), availH / (maxY - minY)));
    origin = Offset(
      size.width / 2 - (minX + maxX) / 2 * scale,
      size.height / 2 - (minY + maxY) / 2 * scale,
    );
    centers = [for (final h in layout.cells) origin + Offset(h.x * scale, h.y * scale)];
    final cellR = scale * 0.93;
    cellPath = Path();
    for (final c in centers) {
      cellPath.addPath(hexPath(cellR), c);
    }
  }

  final BoardLayout layout;
  final Size size;

  /// Pixel length of one hex radius.
  late final double scale;
  late final Offset origin;
  late final List<Offset> centers;

  /// Every cell as one path, so the empty board is drawn in two calls.
  late final Path cellPath;

  static Path hexPath(double r) {
    final p = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3;
      final x = math.cos(a) * r;
      final y = math.sin(a) * r;
      k == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  int? hit(Offset p) {
    final u = (p - origin) / scale;
    return layout.indexOf(Hex.fromPixel(u.dx, u.dy));
  }

  bool matches(BoardLayout l, Size s) => identical(l, layout) && s == size;
}

/// The game board: cells, tokens, move hints and move animations, painted
/// by a single [CustomPainter] for speed.
class HexBoard extends StatefulWidget {
  const HexBoard({
    super.key,
    required this.state,
    required this.looks,
    this.selected,
    this.targets,
    this.pending,
    this.lastMove,
    this.moveSerial = 0,
    this.animate = true,
    this.style = BoardStyle.flat,
    this.onTap,
    this.padding = 8,
  });

  final GameState state;
  final List<PlayerLook> looks;
  final int? selected;

  /// Legal destinations to highlight (null hides hints).
  final TokenTargets? targets;
  final Move? pending;
  final MoveResult? lastMove;
  final int moveSerial;
  final bool animate;
  final BoardStyle style;
  final ValueChanged<int>? onTap;
  final double padding;

  @override
  State<HexBoard> createState() => _HexBoardState();
}

class _HexBoardState extends State<HexBoard> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _select = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  MoveResult? _animating;
  BoardGeometry? _geometry;

  @override
  void initState() {
    super.initState();
    _move.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _animating = null);
    });
    if (widget.selected != null) _select.value = 1;
  }

  @override
  void didUpdateWidget(HexBoard old) {
    super.didUpdateWidget(old);
    if (widget.moveSerial != old.moveSerial && widget.lastMove != null) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (widget.animate && !reduce) {
        _animating = widget.lastMove;
        _move.duration = Duration(milliseconds: widget.lastMove!.captures.isEmpty ? 280 : 560);
        _move.forward(from: 0);
      } else {
        _animating = null;
        _move.value = 1;
      }
    }
    if (widget.selected != old.selected || widget.targets != old.targets) {
      if (widget.selected != null) {
        _select.forward(from: widget.animate ? 0 : 1);
      } else {
        _select.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _select.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final g = _geometry != null && _geometry!.matches(widget.state.layout, size)
            ? _geometry!
            : _geometry = BoardGeometry(widget.state.layout, size, padding: widget.padding);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.onTap == null
              ? null
              : (d) {
                  final i = g.hit(d.localPosition);
                  if (i != null) widget.onTap!(i);
                },
          child: CustomPaint(
            size: size,
            painter: _BoardPainter(
              geometry: g,
              state: widget.state,
              looks: widget.looks,
              palette: palette,
              style: widget.style,
              selected: widget.selected,
              targets: widget.targets,
              pending: widget.pending,
              lastMove: widget.lastMove,
              animating: _animating,
              move: _move,
              select: _select,
              onTap: widget.onTap,
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.geometry,
    required this.state,
    required this.looks,
    required this.palette,
    required this.style,
    required this.selected,
    required this.targets,
    required this.pending,
    required this.lastMove,
    required this.animating,
    required this.move,
    required this.select,
    required this.onTap,
  }) : super(repaint: Listenable.merge([move, select]));

  final BoardGeometry geometry;
  final GameState state;
  final List<PlayerLook> looks;
  final Palette palette;
  final BoardStyle style;
  final int? selected;
  final TokenTargets? targets;
  final Move? pending;
  final MoveResult? lastMove;
  final MoveResult? animating;
  final Animation<double> move;
  final Animation<double> select;
  final ValueChanged<int>? onTap;

  double get tokenR => geometry.scale * 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    _paintCells(canvas);

    // Hints for the selected token.
    final st = Curves.easeOut.transform(select.value);
    final t = targets;
    if (t != null && selected != null && st > 0) {
      final color = looks[state.current].color;
      final hexR = g.scale * 0.93;
      for (final i in t.multiply) {
        canvas.drawPath(
          GeometryPath.at(hexR, g.centers[i]),
          Paint()..color = color.withValues(alpha: 0.2 * st),
        );
        canvas.drawCircle(
          g.centers[i],
          g.scale * 0.13 * st,
          Paint()..color = color.withValues(alpha: 0.85),
        );
      }
      for (final i in t.jump) {
        canvas.drawPath(
          GeometryPath.at(hexR * 0.86, g.centers[i]),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, g.scale * 0.06)
            ..color = color.withValues(alpha: 0.6 * st),
        );
      }
    }

    // Tokens.
    final anim = animating;
    final skip = <int>{};
    if (anim != null) {
      skip.add(anim.move.to);
      for (final c in anim.captures) {
        skip.add(c.cell);
      }
    }
    for (var i = 0; i < state.owners.length; i++) {
      final o = state.owners[i];
      if (o < 0 || skip.contains(i)) continue;
      _token(canvas, g.centers[i], tokenR, o);
    }

    // Marker on the last move once it has settled.
    final lm = lastMove;
    if (anim == null && lm != null && lm.move.to < state.owners.length) {
      canvas.drawCircle(
        g.centers[lm.move.to],
        tokenR + g.scale * 0.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, g.scale * 0.04)
          ..color = palette.text.withValues(alpha: 0.28),
      );
      if (lm.move.type == MoveType.jump && state.owners[lm.move.from] == kEmpty) {
        canvas.drawCircle(
          g.centers[lm.move.from],
          g.scale * 0.1,
          Paint()..color = palette.text.withValues(alpha: 0.18),
        );
      }
    }

    if (anim != null) _paintAnimation(canvas, anim);

    // Selection ring.
    final sel = selected;
    if (sel != null && sel < state.owners.length && state.owners[sel] >= 0) {
      canvas.drawCircle(
        g.centers[sel],
        tokenR + g.scale * 0.13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, g.scale * 0.08)
          ..color = palette.text.withValues(alpha: 0.9 * math.max(0.4, st)),
      );
    }

    // Move waiting for confirmation: a ghost token on the target.
    final p = pending;
    if (p != null) {
      final o = state.current;
      _token(canvas, g.centers[p.to], tokenR, o, opacity: 0.5);
      if (p.type == MoveType.jump) {
        _token(canvas, g.centers[p.from], tokenR, o, opacity: 0.35);
      }
    }
  }

  void _paintCells(Canvas canvas) {
    final g = geometry;
    final edgeW = math.max(1.0, g.scale * 0.05);
    switch (style) {
      case BoardStyle.flat:
        canvas.drawPath(g.cellPath, Paint()..color = palette.board);
        canvas.drawPath(
          g.cellPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = edgeW
            ..color = palette.boardEdge,
        );
      case BoardStyle.outline:
        canvas.drawPath(g.cellPath, Paint()..color = palette.board.withValues(alpha: 0.35));
        canvas.drawPath(
          g.cellPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = edgeW * 1.8
            ..color = palette.boardEdge,
        );
      case BoardStyle.raised:
        canvas.drawPath(
          g.cellPath.shift(Offset(0, g.scale * 0.1)),
          Paint()..color = Colors.black.withValues(alpha: palette.isDark ? 0.45 : 0.14),
        );
        canvas.drawPath(g.cellPath, Paint()..color = palette.board);
        canvas.drawPath(
          g.cellPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = edgeW
            ..color = Color.lerp(palette.board, palette.text, 0.12)!,
        );
    }
  }

  void _token(
    Canvas canvas,
    Offset c,
    double r,
    int owner, {
    double rotation = 0,
    double opacity = 1,
  }) {
    final look = looks[owner % looks.length];
    TokenArt.paint(
      canvas,
      c,
      r,
      look.color,
      look.token,
      symbolColor: palette.symbol,
      rotation: rotation,
      opacity: opacity,
      outline: !palette.isDark,
    );
  }

  void _paintAnimation(Canvas canvas, MoveResult a) {
    final g = geometry;
    final t = move.value;
    final hasCaps = a.captures.isNotEmpty;
    final placeEnd = hasCaps ? 0.45 : 1.0;
    final pt = (t / placeEnd).clamp(0.0, 1.0);
    final ct = hasCaps ? ((t - placeEnd) / (1 - placeEnd)).clamp(0.0, 1.0) : 1.0;
    final from = g.centers[a.move.from];
    final to = g.centers[a.move.to];

    // Captured tokens: spin, shrink, change colour, grow back.
    for (final c in a.captures) {
      final center = g.centers[c.cell];
      if (ct < 0.5) {
        final k = 1 - Curves.easeIn.transform(ct * 2);
        _token(canvas, center, tokenR * k, c.previousOwner, rotation: ct * math.pi);
      } else {
        final k = Curves.easeOutBack.transform((ct - 0.5) * 2);
        _token(canvas, center, tokenR * k, a.player, rotation: (ct - 1) * math.pi);
      }
    }

    // The moving token.
    if (a.move.type == MoveType.multiply) {
      final grow = pt < 0.6
          ? lerpDouble(0.8, 1.1, Curves.easeOut.transform(pt / 0.6))!
          : lerpDouble(1.1, 1.0, Curves.easeInOut.transform((pt - 0.6) / 0.4))!;
      final slide = Curves.easeOutCubic.transform(math.min(1.0, pt * 1.6));
      _token(
        canvas,
        Offset.lerp(from, to, slide)!,
        tokenR * grow,
        a.player,
        opacity: math.min(1.0, 0.3 + pt * 3),
      );
    } else {
      final e = Curves.easeInOutCubic.transform(pt);
      final lift = 1 + 0.18 * math.sin(math.pi * pt);
      final pos = Offset.lerp(from, to, e)! - Offset(0, g.scale * 0.25 * math.sin(math.pi * pt));
      _token(canvas, pos, tokenR * lift, a.player);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.geometry != geometry ||
      old.state != state ||
      old.looks != looks ||
      old.palette != palette ||
      old.style != style ||
      old.selected != selected ||
      old.targets != targets ||
      old.pending != pending ||
      old.lastMove != lastMove ||
      old.animating != animating;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final g = geometry;
    final r = g.scale * 0.8;
    return [
      for (var i = 0; i < state.owners.length; i++)
        CustomPainterSemantics(
          key: ValueKey('cell$i'),
          rect: Rect.fromCircle(center: g.centers[i], radius: r),
          properties: SemanticsProperties(
            label: _cellLabel(i),
            button: onTap != null,
            selected: selected == i,
            textDirection: TextDirection.ltr,
            onTap: onTap == null ? null : () => onTap!(i),
          ),
        ),
    ];
  };

  String _cellLabel(int i) {
    final o = state.owners[i];
    final h = state.layout.cells[i];
    final where = 'Hex ${h.q}, ${h.r}';
    final what = o < 0 ? 'empty' : '${looks[o].name} token';
    final t = targets;
    final hint = t == null
        ? ''
        : t.multiply.contains(i)
        ? ', tap to multiply here'
        : t.jump.contains(i)
        ? ', tap to jump here'
        : '';
    return '$where, $what$hint';
  }

  @override
  bool shouldRebuildSemantics(_BoardPainter old) =>
      old.state != state || old.targets != targets || old.selected != selected || old.geometry != geometry;
}

/// Cached unit hexagon paths shifted to a cell centre.
class GeometryPath {
  static final Map<int, Path> _cache = {};

  static Path at(double r, Offset c) {
    final key = (r * 10).round();
    final base = _cache.putIfAbsent(key, () => BoardGeometry.hexPath(r));
    if (_cache.length > 32) _cache.clear();
    return base.shift(c);
  }
}
