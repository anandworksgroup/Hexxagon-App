import '../engine/game_state.dart';
import '../engine/player.dart';

enum GameMode {
  classic('Classic'),
  aiBattle('AI Battle'),
  quick('Quick Game'),
  challenge('Challenge'),
  daily('Daily Challenge'),
  local('Local 2 Player');

  const GameMode(this.label);
  final String label;

  bool get isLocal => this == GameMode.local;

  /// Modes whose result is recorded against a level id.
  bool get hasLevel => this == classic || this == challenge || this == daily;
}

/// How a game was set up. Together with the [GameState] this is everything
/// needed to resume after the app is closed.
class GameConfig {
  const GameConfig({
    required this.mode,
    required this.title,
    required this.players,
    this.levelId,
    this.undoAllowed = true,
    this.seed = 0,
  });

  final GameMode mode;
  final String title;
  final List<PlayerSlot> players;

  /// Campaign level number, challenge id (`c3`) or daily id (`d20260921`).
  final String? levelId;
  final bool undoAllowed;

  /// Seed of the generated board (quick game / battle / local), so "replay"
  /// gives the same board.
  final int seed;

  int? get levelNumber => mode == GameMode.classic ? int.tryParse(levelId ?? '') : null;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'title': title,
    'players': [for (final p in players) p.toJson()],
    'levelId': levelId,
    'undo': undoAllowed,
    'seed': seed,
  };

  static GameConfig fromJson(Map<String, dynamic> j) => GameConfig(
    mode: GameMode.values.byName(j['mode'] as String),
    title: j['title'] as String,
    players: [
      for (final p in j['players'] as List) PlayerSlot.fromJson(p as Map<String, dynamic>),
    ],
    levelId: j['levelId'] as String?,
    undoAllowed: j['undo'] as bool? ?? true,
    seed: (j['seed'] as num?)?.toInt() ?? 0,
  );
}

/// An unfinished game on disk.
class SavedGame {
  const SavedGame({
    required this.config,
    required this.initial,
    required this.state,
    required this.history,
    required this.usedUndo,
    required this.captures,
    required this.savedAt,
  });

  final GameConfig config;

  /// Opening position, for "restart".
  final GameState initial;
  final GameState state;

  /// Earlier positions for undo (most recent last, capped).
  final List<GameState> history;
  final bool usedUndo;

  /// Tokens the person has captured so far this game.
  final int captures;
  final DateTime savedAt;

  static const maxHistory = 30;

  Map<String, Object?> toJson() => {
    'version': 1,
    'config': config.toJson(),
    'initial': initial.toJson(),
    'state': state.toJson(),
    // History shares the board shape; store only owners/current to keep the
    // file small.
    'history': [
      for (final h in history) {'owners': h.owners, 'current': h.current, 'turn': h.turn, 'quiet': h.quietPlies},
    ],
    'usedUndo': usedUndo,
    'captures': captures,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  /// Throws [FormatException] if anything is inconsistent.
  static SavedGame fromJson(Map<String, dynamic> j) {
    try {
      final config = GameConfig.fromJson(j['config'] as Map<String, dynamic>);
      final state = GameState.fromJson(j['state'] as Map<String, dynamic>);
      final initial = GameState.fromJson(j['initial'] as Map<String, dynamic>);
      if (config.players.length != state.playerCount ||
          initial.layout.size != state.layout.size ||
          state.isOver) {
        throw const FormatException('Saved game does not match its setup');
      }
      final history = <GameState>[];
      for (final raw in j['history'] as List? ?? const []) {
        final h = raw as Map<String, dynamic>;
        final owners = [for (final o in h['owners'] as List) (o as num).toInt()];
        if (owners.length != state.layout.size ||
            owners.any((o) => o < kEmpty || o >= state.playerCount)) {
          throw const FormatException('history');
        }
        history.add(
          state.copyWith(
            owners: owners,
            current: (h['current'] as num).toInt(),
            turn: (h['turn'] as num).toInt(),
            quietPlies: (h['quiet'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      return SavedGame(
        config: config,
        initial: initial,
        state: state,
        history: history,
        usedUndo: j['usedUndo'] as bool? ?? false,
        captures: (j['captures'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.fromMillisecondsSinceEpoch((j['savedAt'] as num?)?.toInt() ?? 0),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid saved game: $e');
    }
  }
}
