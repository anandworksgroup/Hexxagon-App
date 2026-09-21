// Plays AI levels against each other to check that each difficulty beats
// the one below it, and reports the slowest move.
//
//   dart run tool/ai_arena.dart [games]
import 'dart:io';

import 'package:hexadominate/engine/ai/ai_engine.dart';
import 'package:hexadominate/engine/board_layout.dart';
import 'package:hexadominate/engine/game_engine.dart';
import 'package:hexadominate/engine/hex.dart';
import 'package:hexadominate/engine/player.dart';

void main(List<String> args) {
  final games = args.isEmpty ? 10 : int.parse(args.first);
  final pairs = [
    (AiLevel.normal, AiLevel.easy),
    (AiLevel.hard, AiLevel.normal),
    (AiLevel.expert, AiLevel.hard),
  ];
  final layout = BoardLayout(hexagonCells(4));
  final corners = [for (var k = 0; k < 6; k++) const Hex(4, 0).rotate(k)];
  for (final (strong, weak) in pairs) {
    var wins = 0, draws = 0, losses = 0;
    var slowest = 0;
    final watch = Stopwatch()..start();
    for (var g = 0; g < games; g++) {
      final strongFirst = g.isEven;
      final levels = strongFirst ? [strong, weak] : [weak, strong];
      var s = GameEngine.newGame(
        layout: layout,
        starts: [
          [corners[0], corners[2], corners[4]],
          [corners[1], corners[3], corners[5]],
        ],
        humans: const [false, false],
      );
      while (!s.isOver) {
        final t = Stopwatch()..start();
        final m = AiEngine.chooseMove(
          AiRequest(state: s, level: levels[s.current], seed: g * 1000 + s.turn),
        );
        if (t.elapsedMilliseconds > slowest) slowest = t.elapsedMilliseconds;
        s = GameEngine.apply(s, m).after;
      }
      final strongSeat = strongFirst ? 0 : 1;
      if (s.isDraw) {
        draws++;
      } else if (s.winners.contains(strongSeat)) {
        wins++;
      } else {
        losses++;
      }
    }
    stdout.writeln(
      '${strong.label.padRight(6)} vs ${weak.label.padRight(6)}: '
      '$wins W / $draws D / $losses L   slowest move ${slowest}ms, '
      '${watch.elapsed.inSeconds}s total',
    );
  }
}
