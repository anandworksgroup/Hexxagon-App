import 'dart:math' as math;
import 'dart:typed_data';

import '../game_engine.dart';
import '../game_state.dart';
import '../player.dart';
import 'ai_weights.dart';

/// Input for one AI decision. Plain data so it can cross an isolate.
class AiRequest {
  const AiRequest({
    required this.state,
    required this.level,
    required this.seed,
    this.weights,
    this.timeLimitMs,
  });

  final GameState state;
  final AiLevel level;
  final int seed;
  final AiWeights? weights;

  /// Overrides the level's thinking budget (used by tests and tools).
  final int? timeLimitMs;
}

/// Top-level entry point so the UI can run the AI with `compute`.
Move computeAiMove(AiRequest request) => AiEngine.chooseMove(request);

/// Computer opponents. None of them move at random:
///
/// * Easy – prefers captures, then multiplies, with occasional slips.
/// * Normal – one-ply look-ahead scored by the full evaluation.
/// * Hard – minimax with alpha-beta pruning (paranoid for 3–4 players).
/// * Expert – deeper iterative-deepening search with stronger weights.
class AiEngine {
  AiEngine._();

  static Move chooseMove(AiRequest req) {
    final s = req.state;
    final moves = GameEngine.validMoves(s);
    if (moves.isEmpty) throw StateError('AI asked to move with no legal move');
    if (moves.length == 1) return moves.first;
    final rng = math.Random(req.seed);
    switch (req.level) {
      case AiLevel.easy:
        return _easy(s, moves, rng);
      case AiLevel.normal:
        return _Searcher(s, req.weights ?? AiWeights.standard, rng).onePly();
      case AiLevel.hard:
        return _Searcher(s, req.weights ?? AiWeights.standard, rng)
            .iterative(maxDepth: 3, timeLimitMs: req.timeLimitMs ?? 700);
      case AiLevel.expert:
        return _Searcher(s, req.weights ?? AiWeights.expert, rng)
            .iterative(maxDepth: 6, timeLimitMs: req.timeLimitMs ?? 1500);
    }
  }

  static Move _easy(GameState s, List<Move> moves, math.Random rng) {
    if (rng.nextDouble() < 0.22) return moves[rng.nextInt(moves.length)];
    int caps(Move m) {
      var c = 0;
      for (final n in s.layout.adjacent[m.to]) {
        final o = s.owners[n];
        if (o != kEmpty && o != s.current) c++;
      }
      return c;
    }

    final scored = [for (final m in moves) (m, caps(m))];
    final capturing = scored.where((e) => e.$2 > 0).toList();
    if (capturing.isNotEmpty) {
      // Not always the biggest capture: pick among the better half.
      capturing.sort((a, b) => b.$2.compareTo(a.$2));
      final pool = capturing.take(math.max(1, (capturing.length + 1) ~/ 2)).toList();
      return pool[rng.nextInt(pool.length)].$1;
    }
    final multiplies = moves.where((m) => m.type == MoveType.multiply).toList();
    if (multiplies.isNotEmpty) return multiplies[rng.nextInt(multiplies.length)];
    return moves[rng.nextInt(moves.length)];
  }
}

class _Timeout implements Exception {}

/// Mutable board with make/unmake for fast search.
class _Searcher {
  _Searcher(GameState s, this.w, this.rng)
    : n = s.playerCount,
      size = s.layout.size,
      adj = s.layout.adjacent,
      jumps = s.layout.jumps,
      owners = Int8List.fromList(s.owners),
      counts = Int32List(s.playerCount),
      root = s.current,
      current = s.current {
    for (final o in owners) {
      if (o >= 0) {
        counts[o]++;
      } else {
        empty++;
      }
    }
    // Centre of mass of the board, for the strategic term.
    var maxLen = 1;
    for (final c in s.layout.cells) {
      maxLen = math.max(maxLen, c.length);
    }
    centrality = Float64List(size);
    for (var i = 0; i < size; i++) {
      centrality[i] = 1 - s.layout.cells[i].length / maxLen;
    }
  }

  static const double win = 100000;

  final AiWeights w;
  final math.Random rng;
  final int n;
  final int size;
  final List<List<int>> adj;
  final List<List<int>> jumps;
  final Int8List owners;
  final Int32List counts;
  late final Float64List centrality;
  final int root;
  int current;
  int empty = 0;

  /// Captured cells, encoded as cell * 8 + previous owner.
  final List<int> _capStack = [];

  final Stopwatch _clock = Stopwatch();
  int _limitMs = 0;
  int _nodes = 0;

  // Move encoding: from | to << 10 | jump << 20.
  static int _enc(int from, int to, bool jump) => from | (to << 10) | (jump ? 1 << 20 : 0);
  static int _from(int m) => m & 1023;
  static int _to(int m) => (m >> 10) & 1023;
  static bool _isJump(int m) => (m >> 20) & 1 == 1;

  static Move _decode(int m) =>
      Move(_from(m), _to(m), _isJump(m) ? MoveType.jump : MoveType.multiply);

  int _capturesAt(int to, int p) {
    var c = 0;
    for (final a in adj[to]) {
      final o = owners[a];
      if (o >= 0 && o != p) c++;
    }
    return c;
  }

  /// Legal moves for [p], best-first by a cheap heuristic. With [prune],
  /// jumps that capture nothing are dropped (unless nothing else exists).
  List<int> _moves(int p, {required bool prune}) {
    final moves = <int>[];
    final keys = <int>[];
    for (var e = 0; e < size; e++) {
      if (owners[e] != kEmpty) continue;
      for (final a in adj[e]) {
        if (owners[a] == p) {
          moves.add(_enc(a, e, false));
          keys.add(_capturesAt(e, p) * 4 + 3);
          break;
        }
      }
    }
    final jumpMoves = <int>[];
    final jumpKeys = <int>[];
    for (var c = 0; c < size; c++) {
      if (owners[c] != p) continue;
      // Vacating a cell next to our own tokens opens a hole the enemy can use.
      var exposed = 0;
      for (final a in adj[c]) {
        if (owners[a] == p) exposed++;
      }
      for (final j in jumps[c]) {
        if (owners[j] != kEmpty) continue;
        final caps = _capturesAt(j, p);
        if (prune && caps == 0) continue;
        jumpMoves.add(_enc(c, j, true));
        jumpKeys.add(caps * 4 - exposed);
      }
    }
    if (moves.isEmpty && jumpMoves.isEmpty && prune) return _moves(p, prune: false);
    moves.addAll(jumpMoves);
    keys.addAll(jumpKeys);
    final order = List<int>.generate(moves.length, (i) => i)
      ..sort((a, b) => keys[b].compareTo(keys[a]));
    return [for (final i in order) moves[i]];
  }

  /// Plays [m] for [current]; returns how many captures were pushed.
  int _play(int m) {
    final p = current;
    final from = _from(m);
    final to = _to(m);
    owners[to] = p;
    empty--;
    counts[p]++;
    if (_isJump(m)) {
      owners[from] = kEmpty;
      empty++;
      counts[p]--;
    }
    var caps = 0;
    for (final a in adj[to]) {
      final o = owners[a];
      if (o >= 0 && o != p) {
        _capStack.add(a * 8 + o);
        owners[a] = p;
        counts[o]--;
        counts[p]++;
        caps++;
      }
    }
    return caps;
  }

  void _undo(int m, int caps, int player) {
    for (var i = 0; i < caps; i++) {
      final e = _capStack.removeLast();
      final cell = e >> 3;
      final o = e & 7;
      owners[cell] = o;
      counts[o]++;
      counts[player]--;
    }
    final from = _from(m);
    final to = _to(m);
    owners[to] = kEmpty;
    empty++;
    counts[player]--;
    if (_isJump(m)) {
      owners[from] = player;
      empty--;
      counts[player]++;
    }
    current = player;
  }

  bool _hasMove(int p) {
    for (var c = 0; c < size; c++) {
      if (owners[c] != p) continue;
      for (final a in adj[c]) {
        if (owners[a] == kEmpty) return true;
      }
      for (final j in jumps[c]) {
        if (owners[j] == kEmpty) return true;
      }
    }
    return false;
  }

  /// Next player to move after [from], or -1 if the game is over.
  int _next(int from) {
    if (empty == 0) return -1;
    var alive = 0;
    for (var p = 0; p < n; p++) {
      if (counts[p] > 0) alive++;
    }
    if (alive <= 1) return -1;
    for (var i = 1; i <= n; i++) {
      final p = (from + i) % n;
      if (counts[p] > 0 && _hasMove(p)) return p;
    }
    return -1;
  }

  double _terminal() {
    final mine = counts[root];
    var best = 0;
    for (var p = 0; p < n; p++) {
      if (p != root) best = math.max(best, counts[p]);
    }
    final diff = (mine - best).toDouble();
    if (mine > best) return win + diff;
    if (mine == best) return diff;
    return -win + diff;
  }

  /// Static evaluation from the root player's point of view, in token units.
  double _evaluate() {
    final mine = counts[root];
    if (mine == 0) return -win;
    var oppMax = 0;
    var oppSum = 0;
    for (var p = 0; p < n; p++) {
      if (p == root) continue;
      oppSum += counts[p];
      oppMax = math.max(oppMax, counts[p]);
    }
    final territory = mine - oppMax - 0.25 * (oppSum - oppMax);

    var myFront = 0, oppFront = 0;
    var bestOpportunity = 0, worstThreat = 0;
    for (var e = 0; e < size; e++) {
      if (owners[e] != kEmpty) continue;
      var myAdj = 0, oppAdj = 0;
      for (final a in adj[e]) {
        final o = owners[a];
        if (o == root) {
          myAdj++;
        } else if (o >= 0) {
          oppAdj++;
        }
      }
      if (myAdj > 0) myFront++;
      if (oppAdj > 0) oppFront++;
      var myReach = myAdj > 0;
      var oppReach = oppAdj > 0;
      if (!myReach || !oppReach) {
        for (final j in jumps[e]) {
          final o = owners[j];
          if (o == root) {
            myReach = true;
          } else if (o >= 0) {
            oppReach = true;
          }
          if (myReach && oppReach) break;
        }
      }
      if (myReach) {
        final gain = oppAdj + (myAdj > 0 ? 1 : 0);
        if (gain > bestOpportunity) bestOpportunity = gain;
      }
      if (oppReach && myAdj > worstThreat) worstThreat = myAdj;
    }

    var safeMine = 0, safeOpp = 0, bondsMine = 0;
    var centreMine = 0.0;
    for (var c = 0; c < size; c++) {
      final o = owners[c];
      if (o < 0) continue;
      var exposed = false;
      var bonds = 0;
      for (final a in adj[c]) {
        final ao = owners[a];
        if (ao == kEmpty) exposed = true;
        if (ao == o) bonds++;
      }
      if (o == root) {
        if (!exposed) safeMine++;
        bondsMine += bonds;
        centreMine += centrality[c];
      } else if (!exposed) {
        safeOpp++;
      }
    }

    final future = current == root
        ? bestOpportunity - 0.5 * worstThreat
        : 0.35 * bestOpportunity - worstThreat;
    final position = (safeMine - safeOpp * mine / math.max(1, oppSum)) * 0.3;
    final strategy = bondsMine / mine * 0.5 + centreMine / mine;

    return (w.territory * territory +
            w.mobility * 0.25 * (myFront - oppFront) +
            w.futureCapture * future +
            w.position * position +
            w.strategy * strategy) /
        w.territory;
  }

  /// Normal: score every move one ply deep with the full evaluation.
  Move onePly() {
    final moves = _moves(root, prune: false);
    var best = moves.first;
    var bestScore = double.negativeInfinity;
    final captureBonus = w.capture / w.territory * 0.3;
    for (final m in moves) {
      final caps = _play(m);
      final nxt = _next(root);
      double score;
      if (nxt < 0) {
        score = _terminal();
      } else {
        current = nxt;
        score = _evaluate();
      }
      _undo(m, caps, root);
      score += caps * captureBonus + rng.nextDouble() * 0.35;
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return _decode(best);
  }

  /// Hard/Expert: iterative-deepening paranoid alpha-beta.
  Move iterative({required int maxDepth, required int timeLimitMs}) {
    _limitMs = timeLimitMs;
    _clock.start();
    var rootMoves = _moves(root, prune: false);
    // Shuffle equal-looking moves a little so games don't repeat exactly.
    for (var i = rootMoves.length - 1; i > 0; i--) {
      if (rng.nextDouble() < 0.3) {
        final j = i - 1;
        final t = rootMoves[i];
        rootMoves[i] = rootMoves[j];
        rootMoves[j] = t;
      }
    }
    var best = rootMoves.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      try {
        final (move, _) = _root(rootMoves, depth);
        best = move;
        rootMoves = [move, ...rootMoves.where((m) => m != move)];
      } on _Timeout {
        break;
      }
      if (_clock.elapsedMilliseconds * 3 > _limitMs) break;
    }
    return _decode(best);
  }

  (int, double) _root(List<int> moves, int depth) {
    var alpha = double.negativeInfinity;
    const beta = double.infinity;
    var best = moves.first;
    for (final m in moves) {
      final caps = _play(m);
      final nxt = _next(root);
      double score;
      if (nxt < 0) {
        score = _terminal();
      } else {
        current = nxt;
        score = _search(depth - 1, alpha, beta);
      }
      _undo(m, caps, root);
      if (score > alpha) {
        alpha = score;
        best = m;
      }
    }
    return (best, alpha);
  }

  double _search(int depth, double alpha, double beta) {
    if ((++_nodes & 511) == 0 && _clock.elapsedMilliseconds > _limitMs) {
      throw _Timeout();
    }
    if (depth == 0) return _evaluate();
    final p = current;
    final maximizing = p == root;
    final moves = _moves(p, prune: true);
    for (final m in moves) {
      final caps = _play(m);
      final nxt = _next(p);
      double score;
      if (nxt < 0) {
        score = _terminal();
      } else {
        current = nxt;
        try {
          score = _search(depth - 1, alpha, beta);
        } on _Timeout {
          _undo(m, caps, p);
          rethrow;
        }
      }
      _undo(m, caps, p);
      if (maximizing) {
        if (score > alpha) alpha = score;
      } else {
        if (score < beta) beta = score;
      }
      if (alpha >= beta) break;
    }
    return maximizing ? alpha : beta;
  }
}
