import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexadominate/data/local_store.dart';
import 'package:hexadominate/data/repository.dart';
import 'package:hexadominate/data/settings.dart';
import 'package:hexadominate/engine/ai/ai_engine.dart';
import 'package:hexadominate/engine/game_engine.dart';
import 'package:hexadominate/engine/game_state.dart';
import 'package:hexadominate/engine/levels/level.dart';
import 'package:hexadominate/services/feedback.dart';
import 'package:hexadominate/state/game_controller.dart';
import 'package:hexadominate/state/game_factory.dart';
import 'package:hexadominate/state/game_session.dart';
import 'package:hexadominate/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SilentFeedback extends FeedbackService {
  @override
  void apply(Settings s) {}
  @override
  void setForeground(bool foreground) {}
  @override
  Future<void> play(Sfx sfx) async {}
  @override
  void select() {}
  @override
  void move() {}
  @override
  void capture() {}
  @override
  void win() {}
}

final pack = LevelPack.fromJson(
  jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
);

late Directory tmp;

Future<Repository> makeRepo() async =>
    Repository(await SharedPreferences.getInstance(), LocalStore(tmp));

Future<ProviderContainer> makeContainer() async {
  final repo = await makeRepo();
  await repo.saveSettings(
    const Settings(animations: false, aiSpeed: AiSpeed.fast, sound: false, music: false),
  );
  return ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      levelPackProvider.overrideWithValue(pack),
      feedbackProvider.overrideWithValue(SilentFeedback()),
      aiRunnerProvider.overrideWithValue((req) async => AiEngine.chooseMove(req)),
    ],
  );
}

/// Waits until the game hands control back to a person (or ends).
Future<GameView> settle(ProviderContainer c) async {
  for (var i = 0; i < 400; i++) {
    final v = c.read(gameProvider)!;
    if (v.phase == GamePhase.human || v.phase == GamePhase.over) return v;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('Game did not settle');
}

/// Plays the best immediate move for the person through the tap API.
void playGreedy(ProviderContainer c) {
  final v = c.read(gameProvider)!;
  final s = v.state;
  final moves = GameEngine.validMoves(s);
  Move best = moves.first;
  var bestScore = -1;
  for (final m in moves) {
    final r = GameEngine.apply(s, m);
    final score = r.captures.length * 2 + (m.type == MoveType.multiply ? 1 : 0);
    if (score > bestScore) {
      bestScore = score;
      best = m;
    }
  }
  final game = c.read(gameProvider.notifier);
  game.tap(best.from);
  game.tap(best.to);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('hexa_test');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('tap selects, shows targets and plays; engine rejects nonsense taps', () async {
    final c = await makeContainer();
    final settings = c.read(settingsProvider);
    final (config, initial) = levelGame(pack.level(1)!, GameMode.classic, settings);
    final game = c.read(gameProvider.notifier)..start(config, initial);
    var v = await settle(c);
    expect(v.phase, GamePhase.human);

    final mine = v.state.owners.indexOf(0);
    final theirs = v.state.owners.indexOf(1);
    game.tap(theirs); // not our token
    expect(c.read(gameProvider)!.selected, isNull);

    game.tap(mine);
    v = c.read(gameProvider)!;
    expect(v.selected, mine);
    expect(v.targets!.multiply, isNotEmpty);

    final target = v.targets!.multiply.first;
    game.tap(target);
    expect(c.read(gameProvider)!.state.owners[target], 0);
    expect(c.read(savedGameProvider), isNotNull, reason: 'auto-saved after the move');

    v = await settle(c);
    expect(v.state.current, 0);
    expect(v.state.turn, 2, reason: 'the AI replied');
    c.dispose();
  });

  test('undo returns to the previous turn and costs the third star', () async {
    final c = await makeContainer();
    final (config, initial) = levelGame(pack.level(2)!, GameMode.classic, c.read(settingsProvider));
    final game = c.read(gameProvider.notifier)..start(config, initial);
    await settle(c);
    playGreedy(c);
    final v = await settle(c);
    expect(v.canUndo, isTrue);
    game.undo();
    final after = c.read(gameProvider)!;
    expect(after.state.owners, initial.owners);
    expect(after.usedUndo, isTrue);
    c.dispose();
  });

  test('a full level records the result and unlocks the next level', () async {
    final c = await makeContainer();
    final (config, initial) = levelGame(pack.level(1)!, GameMode.classic, c.read(settingsProvider));
    c.read(gameProvider.notifier).start(config, initial);
    var v = await settle(c);
    while (v.phase != GamePhase.over) {
      playGreedy(c);
      v = await settle(c);
    }
    final outcome = v.outcome!;
    final profile = c.read(profileProvider);
    expect(profile.stats.gamesPlayed, 1);
    expect(c.read(savedGameProvider), isNull, reason: 'finished games are not resumable');
    if (outcome.won) {
      expect(outcome.stars, greaterThan(0));
      expect(profile.isUnlocked(2), isTrue);
      expect(profile.achievements.containsKey('first_win'), isTrue);
    } else {
      expect(profile.stats.losses + profile.stats.draws, 1);
    }
    c.dispose();
  });

  test('saved game survives a restart and a corrupt main file', () async {
    final c = await makeContainer();
    final (config, initial) = levelGame(pack.level(5)!, GameMode.classic, c.read(settingsProvider));
    c.read(gameProvider.notifier).start(config, initial);
    await settle(c);
    playGreedy(c);
    final v = await settle(c);
    await c.read(repositoryProvider).flush();
    // Two saves happened (start + moves), so a backup copy exists too.
    final repo2 = await makeRepo();
    final loaded = repo2.loadSavedGame();
    expect(loaded, isNotNull);
    expect(loaded!.state.owners, v.state.owners);
    expect(loaded.config.levelId, '5');

    File('${tmp.path}${Platform.pathSeparator}current_game.json').writeAsStringSync('{"broken": tru');
    final recovered = repo2.loadSavedGame();
    expect(recovered, isNotNull, reason: 'falls back to the .bak copy');

    File('${tmp.path}${Platform.pathSeparator}current_game.json.bak').writeAsStringSync('garbage');
    expect(repo2.loadSavedGame(), isNull, reason: 'corrupt saves are discarded, not crashed on');
    c.dispose();
  });

  test('backup export and import round trip', () async {
    final c = await makeContainer();
    final repo = c.read(repositoryProvider);
    final profile = c.read(profileProvider);
    c.read(profileProvider.notifier).record(
      const GameRecord(
        mode: GameMode.classic,
        levelId: '1',
        won: true,
        draw: false,
        stars: 3,
        share: 0.8,
        moves: 9,
        captures: 4,
      ),
    );
    final exported = jsonEncode(repo.exportBackup(c.read(profileProvider), c.read(settingsProvider)));
    final (p, s) = repo.parseBackup(exported);
    expect(p.starsFor('1'), 3);
    expect(p.stats.wins, 1);
    expect(p.installationId, profile.installationId);
    expect(s.animations, isFalse);
    expect(() => repo.parseBackup('{"app":"other"}'), throwsFormatException);
    expect(() => repo.parseBackup('not json'), throwsFormatException);
    c.dispose();
  });
}
