import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog.dart';
import '../engine/ai/ai_engine.dart';
import '../engine/game_engine.dart';
import '../engine/game_state.dart';
import '../engine/player.dart';
import '../services/feedback.dart';
import 'game_session.dart';
import 'providers.dart';

enum GamePhase {
  /// A person is to move.
  human,

  /// A computer opponent is thinking.
  ai,

  /// A move is being animated; input is ignored.
  animating,

  /// Local game: waiting for the next player to take the device.
  passDevice,
  over,
}

/// The result screen's data.
class GameOutcome {
  const GameOutcome({
    required this.counts,
    required this.winners,
    required this.isDraw,
    required this.won,
    required this.stars,
    required this.previousStars,
    required this.newAchievements,
    required this.newTokens,
    required this.hasNextLevel,
  });

  final List<int> counts;
  final List<int> winners;
  final bool isDraw;

  /// Whether the (single) person won. For local games see [winners].
  final bool won;
  final int stars;
  final int previousStars;
  final List<AchievementDef> newAchievements;
  final List<TokenDef> newTokens;
  final bool hasNextLevel;
}

class GameView {
  const GameView({
    required this.config,
    required this.initial,
    required this.state,
    this.history = const [],
    this.selected,
    this.targets,
    this.pending,
    this.lastMove,
    this.moveSerial = 0,
    this.phase = GamePhase.human,
    this.notice,
    this.noticeSerial = 0,
    this.usedUndo = false,
    this.captures = 0,
    this.outcome,
  });

  final GameConfig config;
  final GameState initial;
  final GameState state;
  final List<GameState> history;
  final int? selected;
  final TokenTargets? targets;

  /// A move waiting for confirmation (when "Confirm move" is on).
  final Move? pending;
  final MoveResult? lastMove;

  /// Increments with every move so the board knows to animate.
  final int moveSerial;
  final GamePhase phase;
  final String? notice;
  final int noticeSerial;
  final bool usedUndo;
  final int captures;
  final GameOutcome? outcome;

  PlayerSlot get currentPlayer => config.players[state.current];

  bool get canUndo =>
      config.undoAllowed && phase == GamePhase.human && history.isNotEmpty;

  GameView copyWith({
    GameState? state,
    List<GameState>? history,
    int? Function()? selected,
    TokenTargets? Function()? targets,
    Move? Function()? pending,
    MoveResult? Function()? lastMove,
    int? moveSerial,
    GamePhase? phase,
    String? Function()? notice,
    int? noticeSerial,
    bool? usedUndo,
    int? captures,
    GameOutcome? Function()? outcome,
  }) => GameView(
    config: config,
    initial: initial,
    state: state ?? this.state,
    history: history ?? this.history,
    selected: selected != null ? selected() : this.selected,
    targets: targets != null ? targets() : this.targets,
    pending: pending != null ? pending() : this.pending,
    lastMove: lastMove != null ? lastMove() : this.lastMove,
    moveSerial: moveSerial ?? this.moveSerial,
    phase: phase ?? this.phase,
    notice: notice != null ? notice() : this.notice,
    noticeSerial: noticeSerial ?? this.noticeSerial,
    usedUndo: usedUndo ?? this.usedUndo,
    captures: captures ?? this.captures,
    outcome: outcome != null ? outcome() : this.outcome,
  );
}

final gameProvider = NotifierProvider<GameController, GameView?>(GameController.new);

/// Runs one game: turn order, AI turns, animation pacing, auto-save and
/// recording the result. Rules come from [GameEngine] only.
class GameController extends Notifier<GameView?> {
  /// Bumped whenever the game changes under a running AI/animation future,
  /// so stale continuations drop out.
  int _epoch = 0;
  final _rng = math.Random();

  FeedbackService get _fx => ref.read(feedbackProvider);

  @override
  GameView? build() {
    // Invalidate pending AI turns and animation timers if torn down.
    ref.onDispose(() => _epoch++);
    return null;
  }

  // Lifecycle --------------------------------------------------------------

  void start(GameConfig config, GameState initial) {
    _epoch++;
    state = GameView(config: config, initial: initial, state: initial, phase: GamePhase.animating);
    _persist();
    _continue(_epoch);
  }

  void resume(SavedGame g) {
    _epoch++;
    state = GameView(
      config: g.config,
      initial: g.initial,
      state: g.state,
      history: g.history,
      usedUndo: g.usedUndo,
      captures: g.captures,
      phase: GamePhase.animating,
    );
    _continue(_epoch);
  }

  void restart() {
    final v = state;
    if (v == null) return;
    start(v.config, v.initial);
  }

  /// Leaves the game screen. The game stays saved unless [discard].
  void leave({bool discard = false}) {
    _epoch++;
    final v = state;
    if (v != null && !v.state.isOver) {
      if (discard) {
        ref.read(savedGameProvider.notifier).clear();
      } else {
        _persist();
      }
    }
    state = null;
  }

  // Input ------------------------------------------------------------------

  void tap(int cell) {
    final v = state;
    if (v == null || v.phase != GamePhase.human) return;
    final s = v.state;
    if (cell < 0 || cell >= s.layout.size) return;

    if (v.pending != null) {
      if (cell == v.pending!.to) {
        confirmPending();
        return;
      }
      state = v.copyWith(pending: () => null);
    }
    final cur = state!;

    if (s.owners[cell] == s.current) {
      if (cur.selected == cell) {
        state = cur.copyWith(selected: () => null, targets: () => null);
      } else {
        state = cur.copyWith(selected: () => cell, targets: () => GameEngine.targetsFor(s, cell));
        _fx.select();
        _fx.play(Sfx.tick);
      }
      return;
    }

    final targets = cur.targets;
    if (cur.selected != null && targets != null && targets.contains(cell)) {
      final move = Move(cur.selected!, cell, targets.typeOf(cell)!);
      if (ref.read(settingsProvider).confirmMove) {
        state = cur.copyWith(pending: () => move);
        _fx.select();
      } else {
        _play(move, _epoch);
      }
      return;
    }
    state = cur.copyWith(selected: () => null, targets: () => null);
  }

  void confirmPending() {
    final v = state;
    final m = v?.pending;
    if (v == null || m == null || v.phase != GamePhase.human) return;
    _play(m, _epoch);
  }

  void cancelPending() {
    final v = state;
    if (v == null) return;
    state = v.copyWith(pending: () => null);
  }

  void passDeviceReady() {
    final v = state;
    if (v == null || v.phase != GamePhase.passDevice) return;
    state = v.copyWith(phase: GamePhase.human);
  }

  /// Steps back to the person's previous turn.
  void undo() {
    final v = state;
    if (v == null || !v.canUndo) return;
    _epoch++;
    final history = List<GameState>.of(v.history);
    final back = history.removeLast();
    state = v.copyWith(
      state: back,
      history: history,
      selected: () => null,
      targets: () => null,
      pending: () => null,
      lastMove: () => null,
      phase: GamePhase.human,
      usedUndo: true,
      notice: () => null,
    );
    _persist();
  }

  // Turn flow --------------------------------------------------------------

  Duration get _animation {
    final s = ref.read(settingsProvider);
    return s.animations ? const Duration(milliseconds: 560) : const Duration(milliseconds: 80);
  }

  void _play(Move m, int epoch) {
    final v = state;
    if (v == null || epoch != _epoch) return;
    final MoveResult result;
    try {
      result = GameEngine.apply(v.state, m);
    } on ArgumentError {
      return; // Never trust the caller: an illegal move is ignored.
    }
    final mover = v.config.players[result.player];
    var history = v.history;
    if (mover.isHuman && v.config.undoAllowed) {
      history = [...history, v.state];
      if (history.length > SavedGame.maxHistory) {
        history = history.sublist(history.length - SavedGame.maxHistory);
      }
    }
    final skippedNames = [for (final p in result.skipped) v.config.players[p].name];
    state = v.copyWith(
      state: result.after,
      history: history,
      selected: () => null,
      targets: () => null,
      pending: () => null,
      lastMove: () => result,
      moveSerial: v.moveSerial + 1,
      phase: GamePhase.animating,
      notice: () => skippedNames.isEmpty
          ? null
          : '${skippedNames.join(' & ')} ${skippedNames.length == 1 ? 'has' : 'have'} no moves',
      noticeSerial: skippedNames.isEmpty ? v.noticeSerial : v.noticeSerial + 1,
      captures: v.captures + (mover.isHuman && !v.config.mode.isLocal ? result.captures.length : 0),
    );

    _fx.move();
    _fx.play(Sfx.move);
    if (result.captures.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (epoch != _epoch) return;
        _fx.capture();
        _fx.play(Sfx.capture);
      });
    }
    _persist();
    Future.delayed(result.captures.isEmpty ? _animation * 0.5 : _animation, () => _continue(epoch));
  }

  void _continue(int epoch) {
    final v = state;
    if (v == null || epoch != _epoch) return;
    final s = v.state;
    if (s.isOver) {
      _finish();
      return;
    }
    final slot = v.config.players[s.current];
    if (slot.isHuman) {
      final last = v.lastMove;
      final handOver = v.config.mode.isLocal &&
          ref.read(settingsProvider).passDevice &&
          last != null &&
          last.player != s.current;
      state = v.copyWith(phase: handOver ? GamePhase.passDevice : GamePhase.human);
      return;
    }
    state = v.copyWith(phase: GamePhase.ai);
    _runAi(epoch, s, slot.ai ?? AiLevel.normal);
  }

  Future<void> _runAi(int epoch, GameState s, AiLevel level) async {
    final speed = ref.read(settingsProvider).aiSpeed.factor;
    final pause = Duration(milliseconds: (500 * speed).round());
    final runner = ref.read(aiRunnerProvider);
    final started = DateTime.now();
    Move move;
    try {
      move = await runner(AiRequest(state: s, level: level, seed: _rng.nextInt(1 << 30)));
    } catch (_) {
      // Should never happen, but a stuck opponent must not hang the game.
      final moves = GameEngine.validMoves(s);
      if (moves.isEmpty) return;
      move = moves[_rng.nextInt(moves.length)];
    }
    final elapsed = DateTime.now().difference(started);
    if (elapsed < pause) await Future.delayed(pause - elapsed);
    if (epoch != _epoch || state?.state != s) return;
    _play(move, epoch);
  }

  void _persist() {
    final v = state;
    if (v == null) return;
    final saved = ref.read(savedGameProvider.notifier);
    if (v.state.isOver) {
      saved.clear();
      return;
    }
    saved.save(
      SavedGame(
        config: v.config,
        initial: v.initial,
        state: v.state,
        history: v.history,
        usedUndo: v.usedUndo,
        captures: v.captures,
        savedAt: DateTime.now(),
      ),
    );
  }

  void _finish() {
    final v = state;
    if (v == null || v.outcome != null) return;
    final s = v.state;
    ref.read(savedGameProvider.notifier).clear();

    final counts = s.counts;
    final config = v.config;
    final humanSeat = config.players.indexWhere((p) => p.isHuman);
    final won = !s.isDraw && s.winners.contains(humanSeat);
    final draw = s.isDraw && s.winners.contains(humanSeat);
    final pack = ref.read(levelPackProvider);
    final level = levelFor(pack, config);
    final stars = level == null || config.mode.isLocal
        ? 0
        : level.starsFor(s, player: humanSeat, usedUndo: v.usedUndo);
    final humanMoves = (s.turn / s.playerCount).ceil();
    final recorded = ref.read(profileProvider.notifier).record(
      GameRecord(
        mode: config.mode,
        levelId: config.levelId,
        won: won,
        draw: draw,
        stars: stars,
        share: GameEngine.share(s, humanSeat),
        moves: humanMoves,
        captures: v.captures,
      ),
    );
    final n = config.levelNumber;
    state = v.copyWith(
      phase: GamePhase.over,
      selected: () => null,
      targets: () => null,
      outcome: () => GameOutcome(
        counts: counts,
        winners: s.winners,
        isDraw: s.isDraw,
        won: won,
        stars: stars,
        previousStars: recorded.previousStars,
        newAchievements: recorded.newAchievements,
        newTokens: recorded.newTokens,
        hasNextLevel: n != null && n < pack.levels.length && won,
      ),
    );
    if (config.mode.isLocal || won) {
      _fx.win();
      _fx.play(recorded.newAchievements.isNotEmpty ? Sfx.achievement : Sfx.success);
    } else {
      _fx.play(Sfx.failure);
    }
  }
}
