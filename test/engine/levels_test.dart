import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hexadominate/engine/game_engine.dart';
import 'package:hexadominate/engine/levels/level.dart';
import 'package:hexadominate/engine/levels/level_generator.dart';

void main() {
  final pack = LevelPack.fromJson(
    jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('bundled levels match the generator', () {
    expect(pack.levels.length, 300);
    expect(pack.challenges.length, 30);
    final fresh = LevelGenerator.campaign(count: 30);
    for (var i = 0; i < fresh.length; i++) {
      expect(jsonEncode(pack.levels[i].toJson()), jsonEncode(fresh[i].toJson()));
    }
  });

  test('every level and challenge is playable from the start', () {
    for (final l in [...pack.levels, ...pack.challenges]) {
      final s = l.initialState();
      expect(s.isOver, isFalse, reason: l.id);
      expect(s.current, 0, reason: l.id);
      expect(GameEngine.validMoves(s), isNotEmpty, reason: l.id);
      expect(l.twoStarShare, lessThan(l.threeStarShare), reason: l.id);
      expect(l.threeStarShare, lessThan(1), reason: l.id);
    }
  });

  test('difficulty ramps from small duels to big boards', () {
    for (final l in pack.levels.take(10)) {
      expect(l.playerCount, 2);
      expect(l.cells.length, lessThanOrEqualTo(37));
    }
    expect(pack.levels.skip(225).any((l) => l.playerCount >= 3), isTrue);
    expect(pack.levels.last.cells.length, greaterThan(40));
  });

  test('daily challenge is the same for everyone on a given date', () {
    final a = LevelGenerator.daily(DateTime(2026, 9, 21));
    final b = LevelGenerator.daily(DateTime(2026, 9, 21));
    final c = LevelGenerator.daily(DateTime(2026, 9, 22));
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(a.id, 'd20260921');
    expect(c.id, isNot(a.id));
    for (var d = 0; d < 366; d++) {
      final l = LevelGenerator.daily(DateTime(2026, 1, 1).add(Duration(days: d)));
      expect(l.initialState().current, 0);
    }
  });

  test('two-player star thresholds', () {
    final l = pack.levels.first;
    expect(l.twoStarShare, 0.6);
    expect(l.threeStarShare, 0.71);
  });
}
