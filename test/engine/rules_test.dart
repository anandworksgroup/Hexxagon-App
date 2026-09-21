import 'package:flutter_test/flutter_test.dart';
import 'package:hexadominate/engine/board_layout.dart';
import 'package:hexadominate/engine/game_engine.dart';
import 'package:hexadominate/engine/game_state.dart';
import 'package:hexadominate/engine/hex.dart';

GameState start(int radius, List<List<Hex>> starts, {List<bool>? humans}) =>
    GameEngine.newGame(
      layout: BoardLayout(hexagonCells(radius)),
      starts: starts,
      humans: humans ?? [true, for (var i = 1; i < starts.length; i++) false],
    );

int idx(GameState s, Hex h) => s.layout.indexOf(h)!;

void main() {
  group('hex geometry', () {
    test('hexagon sizes', () {
      expect(hexagonCells(2).length, 19);
      expect(hexagonCells(4).length, 61);
    });

    test('six neighbours and twelve jump cells in the middle', () {
      final l = BoardLayout(hexagonCells(3));
      final c = l.indexOf(Hex.origin)!;
      expect(l.adjacent[c].length, 6);
      expect(l.jumps[c].length, 12);
      for (final j in l.jumps[c]) {
        expect(l.distance(c, j), 2);
      }
    });

    test('rotation is a 6-cycle and preserves distance', () {
      const h = Hex(2, -1);
      expect(h.rotate(6), h);
      expect(h.rotate(1).length, h.length);
      expect(h.rotate(1), isNot(h));
    });

    test('pixel round trip', () {
      for (final h in hexagonCells(4)) {
        expect(Hex.fromPixel(h.x, h.y), h);
      }
    });
  });

  group('moves', () {
    test('multiply keeps the original token', () {
      final s = start(2, [
        [const Hex(-2, 0)],
        [const Hex(2, 0)],
      ]);
      final from = idx(s, const Hex(-2, 0));
      final to = idx(s, const Hex(-1, 0));
      final r = GameEngine.apply(s, Move(from, to, MoveType.multiply));
      expect(r.after.owners[from], 0);
      expect(r.after.owners[to], 0);
      expect(r.after.countOf(0), 2);
      expect(r.after.current, 1);
      expect(r.after.turn, 1);
    });

    test('jump vacates the origin', () {
      final s = start(2, [
        [const Hex(-2, 0)],
        [const Hex(2, 0)],
      ]);
      final from = idx(s, const Hex(-2, 0));
      final to = idx(s, Hex.origin);
      final r = GameEngine.apply(s, Move(from, to, MoveType.jump));
      expect(r.after.owners[from], kEmpty);
      expect(r.after.owners[to], 0);
      expect(r.after.countOf(0), 1);
    });

    test('illegal moves are rejected', () {
      final s = start(2, [
        [const Hex(-2, 0)],
        [const Hex(2, 0)],
      ]);
      final from = idx(s, const Hex(-2, 0));
      expect(
        () => GameEngine.apply(s, Move(from, idx(s, const Hex(1, 0)), MoveType.jump)),
        throwsArgumentError,
      );
      expect(
        () => GameEngine.apply(s, Move(from, idx(s, Hex.origin), MoveType.multiply)),
        throwsArgumentError,
      );
      expect(
        () => GameEngine.apply(
          s,
          Move(idx(s, const Hex(2, 0)), idx(s, const Hex(1, 0)), MoveType.multiply),
        ),
        throwsArgumentError,
        reason: 'cannot move the opponent token',
      );
    });

    test('capture converts every adjacent enemy token', () {
      final s = start(2, [
        [const Hex(-1, 0)],
        [const Hex(1, 0), const Hex(1, -1), const Hex(0, 1)],
      ]);
      final r = GameEngine.apply(
        s,
        Move(idx(s, const Hex(-1, 0)), idx(s, Hex.origin), MoveType.multiply),
      );
      expect(r.captures.length, 3);
      expect(r.captures.every((c) => c.previousOwner == 1), isTrue);
      expect(r.after.countOf(0), 5);
      expect(r.after.countOf(1), 0);
      expect(r.after.isOver, isTrue);
      expect(r.after.endReason, EndReason.lastStanding);
      expect(r.after.winners, [0]);
    });

    test('multiply moves are deduplicated by destination', () {
      final s = start(2, [
        [const Hex(-1, 0), const Hex(-1, 1)],
        [const Hex(2, -2)],
      ]);
      final dest = GameEngine.validMoves(s)
          .where((m) => m.type == MoveType.multiply)
          .map((m) => m.to)
          .toList();
      expect(dest.toSet().length, dest.length);
    });

    test('targetsFor splits multiply and jump', () {
      final s = start(3, [
        [Hex.origin],
        [const Hex(3, 0)],
      ]);
      final t = GameEngine.targetsFor(s, idx(s, Hex.origin));
      expect(t.multiply.length, 6);
      expect(t.jump.length, 12);
      expect(GameEngine.targetsFor(s, idx(s, const Hex(3, 0))).isEmpty, isTrue);
    });
  });

  group('game end', () {
    test('playing to the end gives a full board and top-score winners', () {
      var s = start(2, [
        [const Hex(-2, 0)],
        [const Hex(2, 0)],
      ]);
      var guard = 0;
      while (!s.isOver && guard++ < 500) {
        final moves = GameEngine.validMoves(s);
        final m = moves.firstWhere(
          (m) => m.type == MoveType.multiply,
          orElse: () => moves.first,
        );
        s = GameEngine.apply(s, m).after;
      }
      expect(s.isOver, isTrue);
      final c = s.counts;
      final best = c.reduce((a, b) => a > b ? a : b);
      expect(s.winners.every((w) => c[w] == best), isTrue);
    });

    test('a stuck player is skipped', () {
      // Player 1 sits on an island with nowhere to go.
      final layout = BoardLayout(const [
        Hex(0, 0),
        Hex(1, 0),
        Hex(2, 0),
        Hex(3, 0),
        Hex(10, 0),
      ]);
      final s = GameEngine.newGame(
        layout: layout,
        starts: const [
          [Hex(0, 0)],
          [Hex(10, 0)],
        ],
        humans: const [true, false],
      );
      final r = GameEngine.apply(
        s,
        Move(layout.indexOf(const Hex(0, 0))!, layout.indexOf(const Hex(1, 0))!, MoveType.multiply),
      );
      expect(r.skipped, [1]);
      expect(r.after.current, 0);
    });

    test('the game ends when the only person is wiped out', () {
      final s = start(3, [
        [const Hex(0, 1)],
        [const Hex(-1, 0), const Hex(1, 0)],
        [const Hex(3, -3)],
      ], humans: [false, true, false]);
      final r = GameEngine.apply(
        s,
        Move(idx(s, const Hex(0, 1)), idx(s, Hex.origin), MoveType.multiply),
      );
      expect(r.after.isOver, isTrue);
      expect(r.after.endReason, EndReason.humansEliminated);
    });
  });

  test('state survives a JSON round trip and rejects corruption', () {
    final s = start(3, [
      [const Hex(-3, 0)],
      [const Hex(3, 0)],
    ]);
    final back = GameState.fromJson(Map<String, dynamic>.from(s.toJson()));
    expect(back.owners, s.owners);
    expect(back.current, s.current);
    final bad = Map<String, dynamic>.from(s.toJson())..['owners'] = [0, 1];
    expect(() => GameState.fromJson(bad), throwsFormatException);
  });
}
