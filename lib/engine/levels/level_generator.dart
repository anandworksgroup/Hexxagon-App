import 'dart:math' as math;

import '../board_layout.dart';
import '../hex.dart';
import '../player.dart';
import 'level.dart';

enum BoardShape {
  hexagon(1),
  stretched(3),
  ring(1),
  hexagram(1),
  triangle(2);

  const BoardShape(this.symmetryStep);

  /// Smallest rotation (in sixths of a turn) that maps the shape onto itself.
  final int symmetryStep;
}

enum SkirmishBoard {
  small('Small'),
  medium('Medium'),
  large('Large'),
  irregular('Irregular');

  const SkirmishBoard(this.label);
  final String label;
}

/// Parameters for one generated board. Everything is symmetric under the
/// rotation that maps players onto each other, so no seat is favoured by the
/// board itself; difficulty comes from the opponents and handicaps.
class LevelRecipe {
  const LevelRecipe({
    required this.shape,
    required this.size,
    required this.opponents,
    this.cluster = 1,
    this.spread = false,
    this.holeOrbits = 0,
    this.handicap = 0,
    this.tip,
  });

  final BoardShape shape;
  final int size;
  final List<AiLevel> opponents;

  /// Tokens per starting group (1–3).
  final int cluster;

  /// Starting groups at several corners instead of one (2–3 players only).
  final bool spread;

  /// Number of symmetric groups of holes (obstacles).
  final int holeOrbits;

  /// Starting tokens taken away from the person.
  final int handicap;

  final String? tip;

  int get players => opponents.length + 1;
}

/// Deterministic board and level generation. The same recipe and seed
/// always give the same level, which is what lets the daily challenge be
/// identical for everyone without a server.
class LevelGenerator {
  LevelGenerator._();

  static List<Hex> shapeCells(BoardShape shape, int size) {
    switch (shape) {
      case BoardShape.hexagon:
        return hexagonCells(size);
      case BoardShape.stretched:
        return [
          for (final h in hexagonCells(size * 2))
            if (h.r.abs() <= size && h.s.abs() <= size && h.q.abs() <= size + 2) h,
        ];
      case BoardShape.ring:
        final inner = math.max(0, size - 3);
        return [for (final h in hexagonCells(size)) if (h.length > inner) h];
      case BoardShape.hexagram:
        return [
          for (final h in hexagonCells(size * 2))
            if ((h.q >= -size && h.r >= -size && h.s >= -size) ||
                (h.q <= size && h.r <= size && h.s <= size))
              h,
        ];
      case BoardShape.triangle:
        return [
          for (final h in hexagonCells(size * 2))
            if (h.q >= -size && h.r >= -size && h.s >= -size) h,
        ];
    }
  }

  /// Builds a valid level, retrying with fresh randomness (and fewer holes)
  /// until the board passes validation.
  static LevelDef build({
    required String id,
    required String name,
    required LevelRecipe recipe,
    required int seed,
  }) {
    final rng = math.Random(seed);
    var r = recipe;
    for (var attempt = 0; attempt < 400; attempt++) {
      final level = _tryBuild(id, name, r, rng);
      if (level != null) return level;
      if (attempt % 40 == 39) {
        r = LevelRecipe(
          shape: r.shape,
          size: r.size,
          opponents: r.opponents,
          cluster: math.max(1, r.cluster - (attempt > 200 ? 1 : 0)),
          spread: attempt > 120 ? false : r.spread,
          holeOrbits: math.max(0, r.holeOrbits - 1),
          handicap: r.handicap,
          tip: r.tip,
        );
      }
    }
    throw StateError('Could not generate level $id');
  }

  static LevelDef? _tryBuild(String id, String name, LevelRecipe r, math.Random rng) {
    final n = r.players;
    final shapeStep = r.shape.symmetryStep;
    final board = shapeCells(r.shape, r.size).toSet();
    var maxLen = 0;
    for (final h in board) {
      maxLen = math.max(maxLen, h.length);
    }
    final rim = board.where((h) => h.length == maxLen).toList()
      ..sort((a, b) => a.angle.compareTo(b.angle));
    if (rim.isEmpty) return null;

    // One starting group, then rotated copies for the other seats.
    final anchor = rim[rng.nextInt(rim.length)];
    final group = _cluster(anchor, r.cluster, board, rng);
    List<List<Hex>> starts;
    if (n == 2 || n == 3) {
      final seatStep = n == 2 ? 3 : 2;
      if (seatStep % shapeStep != 0) return null;
      if (r.spread && shapeStep == 1) {
        // Classic layout: each player holds alternating corners.
        final selfStep = n == 2 ? 2 : 3;
        final seat = [
          for (var k = 0; k < 6; k += selfStep)
            for (final h in group) h.rotate(k),
        ];
        starts = [
          for (var p = 0; p < n; p++) [for (final h in seat) h.rotate(p)],
        ];
      } else {
        starts = [
          for (var p = 0; p < n; p++) [for (final h in group) h.rotate(p * seatStep)],
        ];
      }
    } else if (n == 4) {
      if (3 % shapeStep != 0) return null;
      // Two seats roughly a quarter turn apart plus their mirror images.
      final target = (anchor.angle + 90) % 360;
      double gap(Hex h) {
        final d = (h.angle - target).abs() % 360;
        return math.min(d, 360 - d);
      }

      final others = rim.where((h) => h.distanceTo(anchor) >= 3).toList()
        ..sort((a, b) => gap(a).compareTo(gap(b)));
      if (others.isEmpty) return null;
      final second = _cluster(others.first, r.cluster, board, rng);
      starts = [
        group,
        second,
        [for (final h in group) h.rotate(3)],
        [for (final h in second) h.rotate(3)],
      ];
    } else {
      return null;
    }

    // Handicap: the person starts with fewer tokens.
    if (r.handicap > 0) {
      final keep = math.max(1, starts[0].length - r.handicap);
      starts[0] = starts[0].sublist(0, keep);
    }

    final all = <Hex>{};
    for (final s in starts) {
      for (final h in s) {
        if (!board.contains(h) || !all.add(h)) return null;
      }
    }
    // Different players must not start touching each other.
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        for (final x in starts[a]) {
          for (final y in starts[b]) {
            if (x.distanceTo(y) < 3) return null;
          }
        }
      }
    }

    // Holes: whole rotation orbits, never on or beside a start.
    final cells = Set<Hex>.of(board);
    final candidates = board
        .where((h) => all.every((s) => s.distanceTo(h) >= 2))
        .toList()
      ..sort((a, b) => a.q != b.q ? a.q.compareTo(b.q) : a.r.compareTo(b.r));
    for (var i = 0; i < r.holeOrbits && candidates.isNotEmpty; i++) {
      final pick = candidates[rng.nextInt(candidates.length)];
      for (var k = 0; k < 6; k += shapeStep) {
        cells.remove(pick.rotate(k));
      }
      candidates.removeWhere((h) => !cells.contains(h));
    }
    for (final h in all) {
      if (!cells.contains(h)) return null;
    }
    // Keep boards substantial and fully reachable.
    if (cells.length < board.length * 0.7) return null;
    final ordered = cells.toList()
      ..sort((a, b) => a.q != b.q ? a.q.compareTo(b.q) : a.r.compareTo(b.r));
    final layout = BoardLayout(ordered);
    if (!_connected(layout, all)) return null;

    final level = LevelDef(
      id: id,
      name: name,
      cells: ordered,
      starts: starts,
      opponents: r.opponents,
      twoStarShare: 0,
      threeStarShare: 0,
      tip: r.tip,
    );
    final state = level.initialState();
    if (state.isOver || state.current != 0) return null;
    return _withStars(level);
  }

  static LevelDef _withStars(LevelDef l, {double strictness = 1}) {
    final fair = 1 / l.playerCount;
    double round(double v) => (v * 100).roundToDouble() / 100;
    return LevelDef(
      id: l.id,
      name: l.name,
      cells: l.cells,
      starts: l.starts,
      opponents: l.opponents,
      twoStarShare: round(fair + (1 - fair) * 0.2 * strictness),
      threeStarShare: round(fair + (1 - fair) * 0.42 * strictness),
      tip: l.tip,
    );
  }

  static List<Hex> _cluster(Hex anchor, int size, Set<Hex> board, math.Random rng) {
    final group = [anchor];
    final options = [
      for (final d in Hex.directions)
        if (board.contains(anchor + d)) anchor + d,
    ]..sort((a, b) => b.length.compareTo(a.length));
    for (final h in options) {
      if (group.length >= size) break;
      group.add(h);
    }
    return group;
  }

  static bool _connected(BoardLayout layout, Set<Hex> starts) {
    final seen = List<bool>.filled(layout.size, false);
    final queue = <int>[];
    for (final h in starts) {
      final i = layout.indexOf(h)!;
      seen[i] = true;
      queue.add(i);
    }
    while (queue.isNotEmpty) {
      final c = queue.removeLast();
      for (final list in [layout.adjacent[c], layout.jumps[c]]) {
        for (final n in list) {
          if (!seen[n]) {
            seen[n] = true;
            queue.add(n);
          }
        }
      }
    }
    return seen.every((s) => s);
  }

  // ---------------------------------------------------------------------
  // Campaign

  static const _tips = <int, String>{
    1: 'Tap your token, then tap a glowing hex next to it to multiply.',
    2: 'Hexes two steps away let you jump. A jump moves your token instead of copying it.',
    3: 'Land next to enemy tokens to convert every one of them to your colour.',
    4: 'A bigger board. Grow steadily and avoid leaving gaps beside your tokens.',
    5: 'Missing hexes are holes. You cannot land on them, but you can jump over them.',
    6: 'Multiplying adds a token; jumping does not. Jump only when the capture is worth it.',
    8: 'A token with no empty neighbours can never be captured.',
    10: 'When the board is full, whoever holds the most hexes wins.',
    14: 'Starting with more tokens? Spread out, but keep your groups solid.',
    19: 'Normal opponents look one move ahead. Guard the gaps next to your groups.',
    22: 'Three players! Let your opponents weaken each other.',
    25: 'Final tutorial test. Everything you have learned, on a bigger board.',
  };

  static LevelRecipe recipeFor(int level) {
    final rng = math.Random(level * 7919 + 17);
    final tier = LevelTier.of(level);
    final tip = _tips[level];
    AiLevel pick(double hardShare, AiLevel low, AiLevel high) =>
        rng.nextDouble() < hardShare ? high : low;
    final progress = (level - tier.first) / (tier.last - tier.first); // 0..1

    switch (tier) {
      case LevelTier.tutorial:
        if (level <= 3) {
          return LevelRecipe(
            shape: BoardShape.hexagon,
            size: 2,
            opponents: const [AiLevel.easy],
            cluster: level == 3 ? 2 : 1,
            tip: tip,
          );
        }
        if (level <= 10) {
          return LevelRecipe(
            shape: BoardShape.hexagon,
            size: 3,
            opponents: const [AiLevel.easy],
            cluster: 1 + rng.nextInt(2),
            holeOrbits: level >= 5 ? rng.nextInt(2) + (level == 5 ? 1 : 0) : 0,
            tip: tip,
          );
        }
        if (level == 22 || level == 25) {
          return LevelRecipe(
            shape: level == 22 ? BoardShape.triangle : BoardShape.hexagon,
            size: 3,
            opponents: const [AiLevel.easy, AiLevel.easy],
            cluster: 2,
            holeOrbits: level == 25 ? 1 : 0,
            tip: tip,
          );
        }
        final shapes = [BoardShape.hexagon, BoardShape.stretched, BoardShape.hexagram];
        final shape = shapes[rng.nextInt(shapes.length)];
        return LevelRecipe(
          shape: shape,
          size: shape == BoardShape.hexagon ? 3 : 2,
          opponents: [level >= 19 && level.isOdd ? AiLevel.normal : AiLevel.easy],
          cluster: 1 + rng.nextInt(3),
          spread: level == 14,
          holeOrbits: rng.nextInt(2),
          tip: tip,
        );

      case LevelTier.beginner:
        final three = level % 5 == 0;
        final shapes = three
            ? [BoardShape.hexagon, BoardShape.triangle, BoardShape.hexagram]
            : [BoardShape.hexagon, BoardShape.stretched, BoardShape.hexagram, BoardShape.ring];
        final shape = shapes[rng.nextInt(shapes.length)];
        final ai = pick(0.3 + 0.6 * progress, AiLevel.easy, AiLevel.normal);
        return LevelRecipe(
          shape: shape,
          size: _sizeFor(shape, small: true, rng: rng),
          opponents: three ? [AiLevel.easy, ai] : [ai],
          cluster: 1 + rng.nextInt(3),
          spread: !three && rng.nextDouble() < 0.2,
          holeOrbits: rng.nextInt(3),
        );

      case LevelTier.intermediate:
        final roll = rng.nextDouble();
        final n = roll < 0.6 ? 2 : (roll < 0.9 ? 3 : 4);
        final shape = _shapeFor(n, rng);
        final single = pick(0.25 * progress, AiLevel.normal, AiLevel.hard);
        return LevelRecipe(
          shape: shape,
          size: _sizeFor(shape, small: rng.nextBool(), rng: rng),
          opponents: n == 2
              ? [single]
              : [for (var i = 1; i < n; i++) pick(0.5, AiLevel.easy, AiLevel.normal)],
          cluster: 1 + rng.nextInt(3),
          spread: n < 4 && rng.nextDouble() < 0.25,
          holeOrbits: 1 + rng.nextInt(3),
        );

      case LevelTier.advanced:
        final roll = rng.nextDouble();
        final n = roll < 0.5 ? 2 : (roll < 0.8 ? 3 : 4);
        final shape = _shapeFor(n, rng);
        return LevelRecipe(
          shape: shape,
          size: _sizeFor(shape, small: false, rng: rng),
          opponents: n == 2
              ? [pick(0.45 + 0.4 * progress, AiLevel.normal, AiLevel.hard)]
              : [for (var i = 1; i < n; i++) pick(0.3 + 0.3 * progress, AiLevel.normal, AiLevel.hard)],
          cluster: 1 + rng.nextInt(3),
          spread: n < 4 && rng.nextDouble() < 0.3,
          holeOrbits: rng.nextInt(4),
        );

      case LevelTier.expert:
        final roll = rng.nextDouble();
        final n = roll < 0.5 ? 2 : (roll < 0.8 ? 3 : 4);
        final shape = _shapeFor(n, rng);
        return LevelRecipe(
          shape: shape,
          size: _sizeFor(shape, small: false, rng: rng),
          opponents: n == 2
              ? [level % 10 == 0 ? AiLevel.expert : AiLevel.hard]
              : [for (var i = 1; i < n; i++) pick(0.7, AiLevel.normal, AiLevel.hard)],
          cluster: 1 + rng.nextInt(3),
          spread: n < 4 && rng.nextDouble() < 0.3,
          holeOrbits: rng.nextInt(4),
        );

      case LevelTier.master:
        final roll = rng.nextDouble();
        final n = roll < 0.55 ? 2 : (roll < 0.85 ? 3 : 4);
        final shape = _shapeFor(n, rng);
        final cluster = 2 + rng.nextInt(2);
        return LevelRecipe(
          shape: shape,
          size: _sizeFor(shape, small: false, rng: rng),
          opponents: n == 2
              ? [pick(0.35 + 0.5 * progress, AiLevel.hard, AiLevel.expert)]
              : [for (var i = 1; i < n; i++) pick(0.25 * progress, AiLevel.hard, AiLevel.expert)],
          cluster: cluster,
          spread: n < 4 && rng.nextDouble() < 0.35,
          holeOrbits: rng.nextInt(4),
          handicap: n == 2 && level % 3 == 0 ? 1 : 0,
        );
    }
  }

  static BoardShape _shapeFor(int players, math.Random rng) {
    final options = switch (players) {
      2 => [
        BoardShape.hexagon,
        BoardShape.hexagon,
        BoardShape.stretched,
        BoardShape.ring,
        BoardShape.hexagram,
      ],
      3 => [BoardShape.hexagon, BoardShape.hexagon, BoardShape.triangle, BoardShape.hexagram],
      _ => [BoardShape.hexagon, BoardShape.hexagon, BoardShape.hexagram, BoardShape.ring],
    };
    return options[rng.nextInt(options.length)];
  }

  static int _sizeFor(BoardShape shape, {required bool small, required math.Random rng}) {
    switch (shape) {
      case BoardShape.hexagon:
        return small ? 3 : 4 + (rng.nextDouble() < 0.3 ? 1 : 0);
      case BoardShape.stretched:
        return small ? 3 : 4;
      case BoardShape.ring:
        return small ? 4 : 5;
      case BoardShape.hexagram:
        return small ? 2 : 3;
      case BoardShape.triangle:
        return small ? 3 : 4;
    }
  }

  static LevelDef campaignLevel(int level) {
    final tier = LevelTier.of(level);
    final l = build(
      id: '$level',
      name: 'Level $level',
      recipe: recipeFor(level),
      seed: level * 104729 + 3,
    );
    // Later tiers ask a little less for the extra stars: the opponents are
    // much stronger there.
    final strictness = switch (tier) {
      LevelTier.tutorial || LevelTier.beginner => 1.0,
      LevelTier.intermediate => 0.95,
      LevelTier.advanced => 0.9,
      LevelTier.expert => 0.85,
      LevelTier.master => 0.8,
    };
    return _withStars(l, strictness: strictness);
  }

  static List<LevelDef> campaign({int count = 300}) =>
      [for (var i = 1; i <= count; i++) campaignLevel(i)];

  // ---------------------------------------------------------------------
  // Quick game, AI battle and local boards

  static LevelDef skirmish({
    required SkirmishBoard board,
    required List<AiLevel> opponents,
    required int seed,
  }) {
    final rng = math.Random(seed);
    final n = opponents.length + 1;
    final recipe = switch (board) {
      SkirmishBoard.small => LevelRecipe(shape: BoardShape.hexagon, size: 3, opponents: opponents),
      SkirmishBoard.medium => LevelRecipe(
        shape: BoardShape.hexagon,
        size: 4,
        opponents: opponents,
        spread: n <= 3,
        holeOrbits: 1,
      ),
      SkirmishBoard.large => LevelRecipe(
        shape: BoardShape.hexagon,
        size: 5,
        opponents: opponents,
        cluster: 2,
        spread: n == 2,
        holeOrbits: 1,
      ),
      SkirmishBoard.irregular => () {
        final shape = _shapeFor(n, rng);
        return LevelRecipe(
          shape: shape,
          size: _sizeFor(shape, small: rng.nextBool(), rng: rng),
          opponents: opponents,
          cluster: 1 + rng.nextInt(2),
          holeOrbits: 1 + rng.nextInt(3),
        );
      }(),
    };
    return build(id: 'q$seed', name: board.label, recipe: recipe, seed: seed);
  }

  // ---------------------------------------------------------------------
  // Challenges

  static const challengeThemes = <(String, String)>[
    ('Outnumbered', 'You start with one token against a full group.'),
    ('Three Way', 'A three-player free-for-all on an open board.'),
    ('Four Corners', 'Four players, four corners, one winner.'),
    ('Star Field', 'A six-pointed star full of narrow tips.'),
    ('The Ring', 'No centre to fight over: control the loop.'),
    ('Swiss Cheese', 'A board riddled with holes. Jump wisely.'),
    ('Long Road', 'A stretched board where every gap matters.'),
    ('Delta', 'A triangle for three.'),
    ('Blitz', 'A tiny board against a sharp opponent.'),
    ('Grand Hex', 'The biggest board in the game.'),
  ];

  static LevelRecipe _challengeRecipe(int theme, int rank) {
    final strong = [AiLevel.normal, AiLevel.hard, AiLevel.expert][rank];
    final mid = [AiLevel.easy, AiLevel.normal, AiLevel.hard][rank];
    switch (theme) {
      case 0:
        return LevelRecipe(
          shape: BoardShape.hexagon,
          size: 4,
          opponents: [mid],
          cluster: 3,
          handicap: 2,
        );
      case 1:
        return LevelRecipe(
          shape: BoardShape.hexagon,
          size: 4,
          opponents: [mid, strong],
          cluster: 2,
          holeOrbits: 1,
        );
      case 2:
        return LevelRecipe(
          shape: BoardShape.hexagon,
          size: 5,
          opponents: [mid, strong, mid],
          cluster: 2,
          holeOrbits: 1,
        );
      case 3:
        return LevelRecipe(shape: BoardShape.hexagram, size: 3, opponents: [strong], cluster: 2);
      case 4:
        return LevelRecipe(shape: BoardShape.ring, size: 5, opponents: [strong], cluster: 2);
      case 5:
        return LevelRecipe(
          shape: BoardShape.hexagon,
          size: 5,
          opponents: [strong],
          cluster: 2,
          holeOrbits: 4,
        );
      case 6:
        return LevelRecipe(
          shape: BoardShape.stretched,
          size: 3,
          opponents: [strong],
          cluster: 2,
          holeOrbits: 1,
        );
      case 7:
        return LevelRecipe(
          shape: BoardShape.triangle,
          size: 4,
          opponents: [mid, strong],
          cluster: 2,
        );
      case 8:
        return LevelRecipe(shape: BoardShape.hexagon, size: 2, opponents: [strong]);
      default:
        return LevelRecipe(
          shape: BoardShape.hexagon,
          size: 6,
          opponents: [strong],
          cluster: 3,
          spread: true,
          holeOrbits: 2,
        );
    }
  }

  static List<LevelDef> challenges() {
    const ranks = ['I', 'II', 'III'];
    return [
      for (var t = 0; t < challengeThemes.length; t++)
        for (var r = 0; r < 3; r++)
          build(
            id: 'c${t * 3 + r + 1}',
            name: '${challengeThemes[t].$1} ${ranks[r]}',
            recipe: _challengeRecipe(t, r),
            seed: 900001 + t * 31 + r,
          ),
    ];
  }

  // ---------------------------------------------------------------------
  // Daily challenge

  static String dailyId(DateTime day) =>
      'd${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// The same board for every player on a given calendar day, with no
  /// server: the date is the seed.
  static LevelDef daily(DateTime day) {
    final id = dailyId(day);
    final seed = int.parse(id.substring(1));
    final rng = math.Random(seed);
    final theme = rng.nextInt(challengeThemes.length);
    // Easier early in the week, hardest at the weekend.
    final rank = switch (day.weekday) {
      DateTime.monday || DateTime.tuesday => 0,
      DateTime.saturday || DateTime.sunday => 2,
      _ => 1,
    };
    final base = _challengeRecipe(theme, rank);
    final l = build(id: id, name: 'Daily · ${challengeThemes[theme].$1}', recipe: base, seed: seed);
    return l;
  }
}
