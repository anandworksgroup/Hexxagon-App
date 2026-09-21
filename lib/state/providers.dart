import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog.dart';
import '../data/profile.dart';
import '../data/repository.dart';
import '../data/settings.dart';
import '../engine/ai/ai_engine.dart';
import '../engine/game_state.dart';
import '../engine/levels/level.dart';
import '../engine/levels/level_generator.dart';
import '../services/feedback.dart';
import 'game_session.dart';

/// Set in `main` once local storage is open.
final repositoryProvider = Provider<Repository>((ref) => throw UnimplementedError());

/// Bundled levels, loaded from assets in `main`.
final levelPackProvider = Provider<LevelPack>((ref) => throw UnimplementedError());

final feedbackProvider = Provider<FeedbackService>((ref) => FeedbackService());

/// How AI moves are computed. Real games use a background isolate so the
/// UI never freezes; tests can swap in a synchronous version.
final aiRunnerProvider = Provider<Future<Move> Function(AiRequest)>(
  (ref) => (req) => compute(computeAiMove, req),
);

/// Today's date, overridable for tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// Settings -----------------------------------------------------------------

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    final s = ref.read(repositoryProvider).loadSettings();
    ref.read(feedbackProvider).apply(s);
    return s;
  }

  void update(Settings Function(Settings) change) {
    state = change(state);
    ref.read(feedbackProvider).apply(state);
    ref.read(repositoryProvider).saveSettings(state);
  }

  void replace(Settings s) => update((_) => s);
}

// Profile ------------------------------------------------------------------

/// One finished game as far as progress is concerned.
class GameRecord {
  const GameRecord({
    required this.mode,
    required this.levelId,
    required this.won,
    required this.draw,
    required this.stars,
    required this.share,
    required this.moves,
    required this.captures,
  });

  final GameMode mode;
  final String? levelId;
  final bool won;
  final bool draw;
  final int stars;
  final double share;
  final int moves;
  final int captures;
}

class RecordOutcome {
  const RecordOutcome({
    required this.previousStars,
    required this.newAchievements,
    required this.newTokens,
  });

  final int previousStars;
  final List<AchievementDef> newAchievements;
  final List<TokenDef> newTokens;
}

final profileProvider = NotifierProvider<ProfileController, Profile>(ProfileController.new);

class ProfileController extends Notifier<Profile> {
  @override
  Profile build() => ref.read(repositoryProvider).loadProfile();

  RecordOutcome record(GameRecord r) {
    final before = state;
    var stats = before.stats;
    final records = Map<String, LevelRecord>.of(before.records);
    final previousStars = r.levelId == null ? 0 : before.starsFor(r.levelId!);

    if (r.mode.isLocal) {
      stats = stats.copyWith(
        localGames: stats.localGames + 1,
        totalMoves: stats.totalMoves + r.moves,
      );
    } else {
      final streak = r.won ? stats.currentStreak + 1 : 0;
      stats = stats.copyWith(
        gamesPlayed: stats.gamesPlayed + 1,
        wins: stats.wins + (r.won ? 1 : 0),
        losses: stats.losses + (!r.won && !r.draw ? 1 : 0),
        draws: stats.draws + (r.draw ? 1 : 0),
        totalMoves: stats.totalMoves + r.moves,
        totalCaptures: stats.totalCaptures + r.captures,
        currentStreak: streak,
        bestStreak: streak > stats.bestStreak ? streak : stats.bestStreak,
        dailyCompleted:
            stats.dailyCompleted + (r.mode == GameMode.daily && r.won && previousStars == 0 ? 1 : 0),
      );
      if (r.levelId != null && r.won && r.stars > 0) {
        final fresh = LevelRecord(
          stars: r.stars,
          bestShare: (r.share * 100).round(),
          bestTurns: r.moves,
          completedAt: DateTime.now(),
        );
        final old = records[r.levelId!];
        records[r.levelId!] = old == null ? fresh : old.merge(fresh);
      }
    }

    var next = before.copyWith(records: records, stats: stats);

    // Achievements are checked against the updated profile.
    final levelCount = ref.read(levelPackProvider).levels.length;
    final achievements = Map<String, int>.of(next.achievements);
    final newAchievements = <AchievementDef>[];
    for (final a in achievementCatalog) {
      if (!achievements.containsKey(a.id) && a.earned(next, levelCount)) {
        achievements[a.id] = DateTime.now().millisecondsSinceEpoch;
        newAchievements.add(a);
      }
    }
    next = next.copyWith(achievements: achievements);

    final newTokens = [
      for (var i = 0; i < tokenCatalog.length; i++)
        if (!isTokenUnlocked(i, before) && isTokenUnlocked(i, next)) tokenCatalog[i],
    ];

    state = next;
    ref.read(repositoryProvider).saveProfile(next);
    return RecordOutcome(
      previousStars: previousStars,
      newAchievements: newAchievements,
      newTokens: newTokens,
    );
  }

  void replace(Profile p) {
    final keepId = p.installationId.isEmpty ? state.installationId : p.installationId;
    state = p.copyWith(installationId: keepId);
    ref.read(repositoryProvider).saveProfile(state);
  }

  void reset() => replace(Profile(installationId: state.installationId));
}

// Saved game ---------------------------------------------------------------

/// The unfinished game behind "Continue", if any.
final savedGameProvider = NotifierProvider<SavedGameController, SavedGame?>(
  SavedGameController.new,
);

class SavedGameController extends Notifier<SavedGame?> {
  @override
  SavedGame? build() => ref.read(repositoryProvider).loadSavedGame();

  void save(SavedGame g) {
    state = g;
    ref.read(repositoryProvider).saveGame(g);
  }

  void clear() {
    state = null;
    ref.read(repositoryProvider).clearSavedGame();
  }
}

// Level lookup -------------------------------------------------------------

/// Finds the level behind a config, including regenerating a daily board.
LevelDef? levelFor(LevelPack pack, GameConfig c) {
  final id = c.levelId;
  if (id == null) return null;
  switch (c.mode) {
    case GameMode.classic:
      final n = int.tryParse(id);
      return n == null ? null : pack.level(n);
    case GameMode.challenge:
      return pack.challenge(id);
    case GameMode.daily:
      if (id.length != 9) return null;
      final y = int.tryParse(id.substring(1, 5));
      final m = int.tryParse(id.substring(5, 7));
      final d = int.tryParse(id.substring(7, 9));
      if (y == null || m == null || d == null) return null;
      return LevelGenerator.daily(DateTime(y, m, d));
    default:
      return null;
  }
}
