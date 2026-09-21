import 'board_layout.dart';

/// Owner value of a cell that nobody holds.
const int kEmpty = -1;

enum MoveType { multiply, jump }

/// A move by the current player from one of their tokens to an empty cell.
///
/// A multiply targets a cell 1 step away and keeps the original token; a
/// jump targets a cell 2 steps away and vacates the origin.
class Move {
  const Move(this.from, this.to, this.type);

  final int from;
  final int to;
  final MoveType type;

  Map<String, Object> toJson() => {'from': from, 'to': to, 'type': type.name};

  static Move fromJson(Map<String, dynamic> json) => Move(
    (json['from'] as num).toInt(),
    (json['to'] as num).toInt(),
    MoveType.values.byName(json['type'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is Move && other.from == from && other.to == to && other.type == type;

  @override
  int get hashCode => Object.hash(from, to, type);

  @override
  String toString() => 'Move(${type.name} $from→$to)';
}

enum GameStatus { playing, over }

/// Why a finished game ended.
enum EndReason { boardFull, noMoves, lastStanding, humansEliminated, stalemate }

/// An immutable snapshot of a game in progress.
///
/// `owners[i]` is the player index holding cell i, or [kEmpty].
class GameState {
  GameState({
    required this.layout,
    required List<int> owners,
    required this.playerCount,
    required this.current,
    required this.turn,
    required this.quietPlies,
    required List<bool> humans,
    this.status = GameStatus.playing,
    this.endReason,
    List<int> winners = const [],
  }) : owners = List.unmodifiable(owners),
       humans = List.unmodifiable(humans),
       winners = List.unmodifiable(winners);

  final BoardLayout layout;
  final List<int> owners;
  final int playerCount;

  /// Player index whose turn it is (meaningless once the game is over).
  final int current;

  /// Number of moves played so far.
  final int turn;

  /// Consecutive moves without a multiply; used to stop endless jumping.
  final int quietPlies;

  /// Which players are people. When every person has been wiped out the
  /// game ends rather than making them watch the computers finish.
  final List<bool> humans;

  final GameStatus status;
  final EndReason? endReason;

  /// Player indices sharing the top score. More than one means a draw.
  final List<int> winners;

  bool get isOver => status == GameStatus.over;
  bool get isDraw => isOver && winners.length > 1;

  int countOf(int player) {
    var n = 0;
    for (final o in owners) {
      if (o == player) n++;
    }
    return n;
  }

  List<int> get counts {
    final c = List<int>.filled(playerCount, 0);
    for (final o in owners) {
      if (o >= 0) c[o]++;
    }
    return c;
  }

  int get emptyCount {
    var n = 0;
    for (final o in owners) {
      if (o == kEmpty) n++;
    }
    return n;
  }

  GameState copyWith({
    List<int>? owners,
    int? current,
    int? turn,
    int? quietPlies,
    GameStatus? status,
    EndReason? endReason,
    List<int>? winners,
  }) => GameState(
    layout: layout,
    owners: owners ?? this.owners,
    playerCount: playerCount,
    current: current ?? this.current,
    turn: turn ?? this.turn,
    quietPlies: quietPlies ?? this.quietPlies,
    humans: humans,
    status: status ?? this.status,
    endReason: endReason ?? this.endReason,
    winners: winners ?? this.winners,
  );

  Map<String, Object?> toJson() => {
    'cells': layout.toJson(),
    'owners': owners,
    'players': playerCount,
    'current': current,
    'turn': turn,
    'quiet': quietPlies,
    'humans': humans,
    'status': status.name,
    'endReason': endReason?.name,
    'winners': winners,
  };

  /// Parses and validates a saved state. Throws [FormatException] on any
  /// inconsistency so a corrupt save is rejected instead of half-loaded.
  static GameState fromJson(Map<String, dynamic> json) {
    try {
      final layout = BoardLayout.fromJson(json['cells']);
      final players = (json['players'] as num).toInt();
      final owners = [for (final o in json['owners'] as List) (o as num).toInt()];
      final humans = [for (final h in json['humans'] as List) h as bool];
      final current = (json['current'] as num).toInt();
      if (players < 2 || players > 6) throw const FormatException('players');
      if (owners.length != layout.size) throw const FormatException('owners length');
      if (owners.any((o) => o < kEmpty || o >= players)) {
        throw const FormatException('owner value');
      }
      if (humans.length != players) throw const FormatException('humans');
      if (current < 0 || current >= players) throw const FormatException('current');
      final reason = json['endReason'] as String?;
      return GameState(
        layout: layout,
        owners: owners,
        playerCount: players,
        current: current,
        turn: (json['turn'] as num).toInt(),
        quietPlies: (json['quiet'] as num?)?.toInt() ?? 0,
        humans: humans,
        status: GameStatus.values.byName(json['status'] as String),
        endReason: reason == null ? null : EndReason.values.byName(reason),
        winners: [for (final w in (json['winners'] as List? ?? const [])) (w as num).toInt()],
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid game state: $e');
    }
  }
}
