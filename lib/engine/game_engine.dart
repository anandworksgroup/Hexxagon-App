import 'board_layout.dart';
import 'game_state.dart';
import 'hex.dart';

/// A cell converted by a capture, with the player who lost it.
class Capture {
  const Capture(this.cell, this.previousOwner);
  final int cell;
  final int previousOwner;
}

/// Everything the UI needs to animate and report one move.
class MoveResult {
  const MoveResult({
    required this.before,
    required this.after,
    required this.move,
    required this.player,
    required this.captures,
    required this.skipped,
  });

  final GameState before;
  final GameState after;
  final Move move;
  final int player;
  final List<Capture> captures;

  /// Players passed over after this move because they had no legal move.
  final List<int> skipped;
}

/// Legal destinations for one token, split by move type.
class TokenTargets {
  const TokenTargets(this.multiply, this.jump);
  final List<int> multiply;
  final List<int> jump;
  bool get isEmpty => multiply.isEmpty && jump.isEmpty;
  bool contains(int cell) => multiply.contains(cell) || jump.contains(cell);
  MoveType? typeOf(int cell) => multiply.contains(cell)
      ? MoveType.multiply
      : jump.contains(cell)
      ? MoveType.jump
      : null;
}

/// The single source of truth for the rules. The UI and the AI only ever ask
/// this class what is legal and what a move does.
class GameEngine {
  GameEngine._();

  /// Moves in a row with no multiply before the game is called. Only jumps
  /// can repeat forever, so this only ever triggers on degenerate boards.
  static const int stalemateLimit = 80;

  /// Builds the opening position and picks the first player able to move.
  static GameState newGame({
    required BoardLayout layout,
    required List<List<Hex>> starts,
    required List<bool> humans,
  }) {
    if (starts.length < 2) throw ArgumentError('Need at least two players');
    if (humans.length != starts.length) throw ArgumentError('humans length');
    final owners = List<int>.filled(layout.size, kEmpty);
    for (var p = 0; p < starts.length; p++) {
      for (final h in starts[p]) {
        final i = layout.indexOf(h);
        if (i == null) throw ArgumentError('Start $h is not on the board');
        if (owners[i] != kEmpty) throw ArgumentError('Start $h is shared');
        owners[i] = p;
      }
    }
    final draft = GameState(
      layout: layout,
      owners: owners,
      playerCount: starts.length,
      current: starts.length - 1,
      turn: 0,
      quietPlies: 0,
      humans: humans,
    );
    // Resolve "whose turn" with the same logic used after every move so an
    // opening where player 0 cannot move is still handled correctly.
    return _advance(draft, draft.owners, madeMultiply: true, isOpening: true).$1;
  }

  /// Legal targets for the token on [cell], or empty if it is not the
  /// current player's token.
  static TokenTargets targetsFor(GameState s, int cell) {
    if (s.isOver || cell < 0 || cell >= s.layout.size) {
      return const TokenTargets([], []);
    }
    if (s.owners[cell] != s.current) return const TokenTargets([], []);
    return TokenTargets(
      [for (final n in s.layout.adjacent[cell]) if (s.owners[n] == kEmpty) n],
      [for (final n in s.layout.jumps[cell]) if (s.owners[n] == kEmpty) n],
    );
  }

  /// All legal moves for [player]. Multiplies into the same cell are
  /// equivalent whatever token they come from, so each destination is
  /// listed once.
  static List<Move> validMoves(GameState s, [int? player]) {
    final p = player ?? s.current;
    if (s.isOver) return const [];
    final layout = s.layout;
    final owners = s.owners;
    final moves = <Move>[];
    for (var e = 0; e < layout.size; e++) {
      if (owners[e] != kEmpty) continue;
      for (final n in layout.adjacent[e]) {
        if (owners[n] == p) {
          moves.add(Move(n, e, MoveType.multiply));
          break;
        }
      }
    }
    for (var c = 0; c < layout.size; c++) {
      if (owners[c] != p) continue;
      for (final j in layout.jumps[c]) {
        if (owners[j] == kEmpty) moves.add(Move(c, j, MoveType.jump));
      }
    }
    return moves;
  }

  static bool hasAnyMove(GameState s, int player) =>
      _hasAnyMove(s.layout, s.owners, player);

  static bool _hasAnyMove(BoardLayout layout, List<int> owners, int player) {
    for (var c = 0; c < layout.size; c++) {
      if (owners[c] != player) continue;
      for (final n in layout.adjacent[c]) {
        if (owners[n] == kEmpty) return true;
      }
      for (final n in layout.jumps[c]) {
        if (owners[n] == kEmpty) return true;
      }
    }
    return false;
  }

  static bool isLegal(GameState s, Move m) {
    if (s.isOver) return false;
    final size = s.layout.size;
    if (m.from < 0 || m.from >= size || m.to < 0 || m.to >= size) return false;
    if (s.owners[m.from] != s.current || s.owners[m.to] != kEmpty) return false;
    final d = s.layout.distance(m.from, m.to);
    return m.type == MoveType.multiply ? d == 1 : d == 2;
  }

  /// Plays [m] for the current player. Throws [ArgumentError] if illegal.
  static MoveResult apply(GameState s, Move m) {
    if (!isLegal(s, m)) throw ArgumentError('Illegal move $m');
    final player = s.current;
    final owners = List<int>.of(s.owners);
    owners[m.to] = player;
    if (m.type == MoveType.jump) owners[m.from] = kEmpty;
    final captures = <Capture>[];
    for (final n in s.layout.adjacent[m.to]) {
      final o = owners[n];
      if (o != kEmpty && o != player) {
        captures.add(Capture(n, o));
        owners[n] = player;
      }
    }
    final (after, skipped) = _advance(
      s,
      owners,
      madeMultiply: m.type == MoveType.multiply,
    );
    return MoveResult(
      before: s,
      after: after,
      move: m,
      player: player,
      captures: captures,
      skipped: skipped,
    );
  }

  /// Checks the end conditions and hands the turn to the next player who
  /// can move, skipping anyone who is stuck.
  static (GameState, List<int>) _advance(
    GameState s,
    List<int> owners, {
    required bool madeMultiply,
    bool isOpening = false,
  }) {
    final n = s.playerCount;
    final counts = List<int>.filled(n, 0);
    var empty = 0;
    for (final o in owners) {
      if (o == kEmpty) {
        empty++;
      } else {
        counts[o]++;
      }
    }
    final turn = isOpening ? 0 : s.turn + 1;
    final quiet = madeMultiply ? 0 : s.quietPlies + 1;

    GameState finish(EndReason reason) {
      final best = counts.reduce((a, b) => a > b ? a : b);
      return GameState(
        layout: s.layout,
        owners: owners,
        playerCount: n,
        current: s.current,
        turn: turn,
        quietPlies: quiet,
        humans: s.humans,
        status: GameStatus.over,
        endReason: reason,
        winners: [for (var p = 0; p < n; p++) if (counts[p] == best) p],
      );
    }

    final alive = [for (var p = 0; p < n; p++) if (counts[p] > 0) p];
    if (empty == 0) return (finish(EndReason.boardFull), const []);
    if (alive.length <= 1) return (finish(EndReason.lastStanding), const []);
    final anyHuman = s.humans.contains(true);
    if (anyHuman && !alive.any((p) => s.humans[p])) {
      return (finish(EndReason.humansEliminated), const []);
    }
    if (quiet >= stalemateLimit) return (finish(EndReason.stalemate), const []);

    final skipped = <int>[];
    for (var i = 1; i <= n; i++) {
      final p = (s.current + i) % n;
      if (counts[p] == 0) continue;
      if (_hasAnyMove(s.layout, owners, p)) {
        return (
          GameState(
            layout: s.layout,
            owners: owners,
            playerCount: n,
            current: p,
            turn: turn,
            quietPlies: quiet,
            humans: s.humans,
          ),
          skipped,
        );
      }
      if (p != s.current || isOpening) skipped.add(p);
    }
    return (finish(EndReason.noMoves), const []);
  }

  /// Share of the occupied cells held by [player], 0..1.
  static double share(GameState s, int player) {
    final counts = s.counts;
    final total = counts.fold<int>(0, (a, b) => a + b);
    return total == 0 ? 0 : counts[player] / total;
  }
}
