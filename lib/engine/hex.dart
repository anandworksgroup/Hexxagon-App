import 'dart:math' as math;

/// A hex cell address in axial coordinates (q, r). The third cube
/// coordinate is implied: s = -q - r.
///
/// Boards are laid out flat-top. Everything that reasons about the board
/// (neighbours, jumps, symmetry, level generation, the AI) works on these
/// coordinates; pixels are only derived at paint time.
class Hex {
  const Hex(this.q, this.r);

  final int q;
  final int r;

  int get s => -q - r;

  static const origin = Hex(0, 0);

  /// The six axial directions, clockwise starting east.
  static const directions = <Hex>[
    Hex(1, 0),
    Hex(1, -1),
    Hex(0, -1),
    Hex(-1, 0),
    Hex(-1, 1),
    Hex(0, 1),
  ];

  Hex operator +(Hex o) => Hex(q + o.q, r + o.r);
  Hex operator -(Hex o) => Hex(q - o.q, r - o.r);
  Hex scale(int k) => Hex(q * k, r * k);

  Hex neighbor(int direction) => this + directions[direction % 6];

  int distanceTo(Hex o) {
    final dq = (q - o.q).abs();
    final dr = (r - o.r).abs();
    final ds = (s - o.s).abs();
    return math.max(dq, math.max(dr, ds));
  }

  int get length => distanceTo(origin);

  /// Rotates 60° clockwise around the origin.
  Hex rotate60() => Hex(-r, q + r);

  Hex rotate(int sixths) {
    var h = this;
    for (var i = 0; i < ((sixths % 6) + 6) % 6; i++) {
      h = h.rotate60();
    }
    return h;
  }

  /// Every cell exactly [radius] steps away.
  static List<Hex> ring(Hex center, int radius) {
    if (radius == 0) return [center];
    final out = <Hex>[];
    var h = center + directions[4].scale(radius);
    for (var side = 0; side < 6; side++) {
      for (var step = 0; step < radius; step++) {
        out.add(h);
        h = h.neighbor(side);
      }
    }
    return out;
  }

  /// Unit-size flat-top pixel centre.
  double get x => 1.5 * q;
  double get y => math.sqrt(3) * (r + q / 2);

  /// Angle of the pixel centre around the origin, in degrees [0, 360).
  double get angle {
    final a = math.atan2(y, x) * 180 / math.pi;
    return a < 0 ? a + 360 : a;
  }

  /// Rounds fractional axial coordinates to the containing hex.
  static Hex round(double fq, double fr) {
    final fs = -fq - fr;
    var rq = fq.round();
    var rr = fr.round();
    final rs = fs.round();
    final dq = (rq - fq).abs();
    final dr = (rr - fr).abs();
    final ds = (rs - fs).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return Hex(rq, rr);
  }

  /// Inverse of [x]/[y] for a unit-size flat-top grid.
  static Hex fromPixel(double px, double py) {
    final fq = (2 / 3) * px;
    final fr = (-1 / 3) * px + (math.sqrt(3) / 3) * py;
    return round(fq, fr);
  }

  List<int> toJson() => [q, r];

  static Hex fromJson(Object? json) {
    final list = json as List;
    return Hex((list[0] as num).toInt(), (list[1] as num).toInt());
  }

  @override
  bool operator ==(Object other) => other is Hex && other.q == q && other.r == r;

  @override
  int get hashCode => q * 7919 + r;

  @override
  String toString() => 'Hex($q, $r)';
}

/// All cells within [radius] of the origin: a regular hexagon board.
List<Hex> hexagonCells(int radius) {
  final out = <Hex>[];
  for (var q = -radius; q <= radius; q++) {
    final r1 = math.max(-radius, -q - radius);
    final r2 = math.min(radius, -q + radius);
    for (var r = r1; r <= r2; r++) {
      out.add(Hex(q, r));
    }
  }
  return out;
}
