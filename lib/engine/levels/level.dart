import '../board_layout.dart';
import '../game_engine.dart';
import '../game_state.dart';
import '../hex.dart';
import '../player.dart';

enum LevelTier {
  tutorial('Tutorial', 1, 25),
  beginner('Beginner', 26, 75),
  intermediate('Intermediate', 76, 125),
  advanced('Advanced', 126, 175),
  expert('Expert', 176, 225),
  master('Master', 226, 300);

  const LevelTier(this.label, this.first, this.last);
  final String label;
  final int first;
  final int last;

  static LevelTier of(int levelId) =>
      values.firstWhere((t) => levelId >= t.first && levelId <= t.last, orElse: () => master);
}

/// A level as data: the board, who starts where, the opponents and the
/// star thresholds. Player 0 is always the person and moves first.
///
/// Levels are generated offline by `tool/generate_levels.dart` into
/// `assets/levels/levels.json`; nothing about a level lives in UI code.
class LevelDef {
  const LevelDef({
    required this.id,
    required this.name,
    required this.cells,
    required this.starts,
    required this.opponents,
    required this.twoStarShare,
    required this.threeStarShare,
    this.tip,
  });

  /// Numeric for campaign levels; challenges use ids like `c7` and the daily
  /// challenge `d20260921`.
  final String id;
  final String name;
  final List<Hex> cells;

  /// Starting tokens per player; index 0 is the person.
  final List<List<Hex>> starts;

  /// AI level for each opponent (players 1..n).
  final List<AiLevel> opponents;

  /// ★★ needs at least this share of the occupied cells at the end.
  final double twoStarShare;

  /// ★★★ needs at least this share, without using undo.
  final double threeStarShare;

  /// Short hint shown on the level intro (tutorial levels).
  final String? tip;

  int get playerCount => starts.length;

  int? get number => int.tryParse(id);

  LevelTier? get tier => number == null ? null : LevelTier.of(number!);

  BoardLayout layout() => BoardLayout(cells);

  GameState initialState({List<bool>? humans}) => GameEngine.newGame(
    layout: layout(),
    starts: starts,
    humans: humans ?? [true, for (final _ in opponents) false],
  );

  /// Stars earned for a finished game, 0 when the person did not win.
  int starsFor(GameState end, {required int player, required bool usedUndo}) {
    if (!end.isOver || end.isDraw || !end.winners.contains(player)) return 0;
    final share = GameEngine.share(end, player);
    if (share >= threeStarShare && !usedUndo) return 3;
    if (share >= twoStarShare) return 2;
    return 1;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'cells': [for (final c in cells) c.toJson()],
    'starts': [
      for (final s in starts) [for (final h in s) h.toJson()],
    ],
    'ai': [for (final a in opponents) a.name],
    'two': twoStarShare,
    'three': threeStarShare,
    if (tip != null) 'tip': tip,
  };

  static LevelDef fromJson(Map<String, dynamic> json) => LevelDef(
    id: json['id'].toString(),
    name: json['name'] as String,
    cells: [for (final c in json['cells'] as List) Hex.fromJson(c)],
    starts: [
      for (final s in json['starts'] as List) [for (final h in s as List) Hex.fromJson(h)],
    ],
    opponents: [for (final a in json['ai'] as List) AiLevel.values.byName(a as String)],
    twoStarShare: (json['two'] as num).toDouble(),
    threeStarShare: (json['three'] as num).toDouble(),
    tip: json['tip'] as String?,
  );
}

/// All bundled content: the campaign and the challenge boards.
class LevelPack {
  LevelPack({required this.levels, required this.challenges});

  final List<LevelDef> levels;
  final List<LevelDef> challenges;

  LevelDef? level(int number) =>
      number >= 1 && number <= levels.length ? levels[number - 1] : null;

  LevelDef? challenge(String id) {
    for (final c in challenges) {
      if (c.id == id) return c;
    }
    return null;
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'levels': [for (final l in levels) l.toJson()],
    'challenges': [for (final c in challenges) c.toJson()],
  };

  static LevelPack fromJson(Map<String, dynamic> json) => LevelPack(
    levels: [for (final l in json['levels'] as List) LevelDef.fromJson(l as Map<String, dynamic>)],
    challenges: [
      for (final c in json['challenges'] as List) LevelDef.fromJson(c as Map<String, dynamic>),
    ],
  );
}
