import '../data/catalog.dart';
import '../data/settings.dart';
import '../engine/game_state.dart';
import '../engine/levels/level.dart';
import '../engine/levels/level_generator.dart';
import '../engine/player.dart';
import 'game_session.dart';

/// Opponent names, one per seat after the person.
const _aiNames = ['Nova', 'Onyx', 'Vega'];

/// Seats for a game: the person uses their chosen colour and token, every
/// other seat gets a different colour *and* a different symbol so players
/// can be told apart without relying on colour.
List<PlayerSlot> seatPlayers({
  required Settings settings,
  required int count,
  required List<bool> humans,
  List<AiLevel> ai = const [],
}) {
  final colors = {settings.playerColor, for (var i = 0; i < colorNames.length; i++) i}.toList();
  final tokens = {settings.playerToken, 2, 5, 3, 4, 1, 0, 6, 7, 8, 9}.toList();
  var aiIndex = 0;
  var humanIndex = 0;
  final humanCount = humans.where((h) => h).length;
  return [
    for (var i = 0; i < count; i++)
      if (humans[i])
        PlayerSlot(
          name: humanCount == 1 ? 'You' : 'Player ${++humanIndex}',
          kind: PlayerKind.human,
          colorIndex: colors[i % colors.length],
          tokenIndex: tokens[i % tokens.length],
        )
      else
        PlayerSlot(
          name: _aiNames[aiIndex % _aiNames.length],
          kind: PlayerKind.ai,
          colorIndex: colors[i % colors.length],
          tokenIndex: tokens[i % tokens.length],
          ai: ai[aiIndex++],
        ),
  ];
}

(GameConfig, GameState) levelGame(LevelDef level, GameMode mode, Settings settings) {
  final players = seatPlayers(
    settings: settings,
    count: level.playerCount,
    humans: [true, for (final _ in level.opponents) false],
    ai: level.opponents,
  );
  final title = switch (mode) {
    GameMode.classic => level.name,
    _ => level.name,
  };
  return (
    GameConfig(
      mode: mode,
      title: title,
      players: players,
      levelId: level.id,
      undoAllowed: mode != GameMode.daily,
    ),
    level.initialState(),
  );
}

(GameConfig, GameState) skirmishGame({
  required GameMode mode,
  required SkirmishBoard board,
  required List<AiLevel> opponents,
  required Settings settings,
  required int seed,
}) {
  final level = LevelGenerator.skirmish(board: board, opponents: opponents, seed: seed);
  final players = seatPlayers(
    settings: settings,
    count: level.playerCount,
    humans: [true, for (final _ in opponents) false],
    ai: opponents,
  );
  final strongest = opponents.reduce((a, b) => a.index >= b.index ? a : b);
  return (
    GameConfig(
      mode: mode,
      title: '${board.label} · ${strongest.label}',
      players: players,
      seed: seed,
    ),
    level.initialState(),
  );
}

(GameConfig, GameState) localGame({
  required SkirmishBoard board,
  required Settings settings,
  required int seed,
}) {
  // Board generation needs opponent entries; they are not used as AI here.
  final level = LevelGenerator.skirmish(board: board, opponents: const [AiLevel.normal], seed: seed);
  final players = seatPlayers(settings: settings, count: 2, humans: const [true, true]);
  return (
    GameConfig(mode: GameMode.local, title: '${board.label} · 2 Players', players: players, seed: seed),
    level.initialState(humans: const [true, true]),
  );
}
