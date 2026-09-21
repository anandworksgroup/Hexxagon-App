/// Best result on one level, challenge or daily board.
class LevelRecord {
  const LevelRecord({
    required this.stars,
    required this.bestShare,
    required this.bestTurns,
    required this.completedAt,
  });

  final int stars;

  /// Best end-of-game share of the board, in percent.
  final int bestShare;

  /// Fewest moves to a win.
  final int bestTurns;
  final DateTime completedAt;

  bool get completed => stars > 0;

  LevelRecord merge(LevelRecord other) => LevelRecord(
    stars: stars > other.stars ? stars : other.stars,
    bestShare: bestShare > other.bestShare ? bestShare : other.bestShare,
    bestTurns: bestTurns == 0
        ? other.bestTurns
        : (other.bestTurns == 0 || bestTurns < other.bestTurns ? bestTurns : other.bestTurns),
    completedAt: completedAt.isBefore(other.completedAt) ? completedAt : other.completedAt,
  );

  Map<String, Object> toJson() => {
    'stars': stars,
    'share': bestShare,
    'turns': bestTurns,
    'at': completedAt.millisecondsSinceEpoch,
  };

  static LevelRecord fromJson(Map<String, dynamic> j) => LevelRecord(
    stars: ((j['stars'] as num?)?.toInt() ?? 0).clamp(0, 3),
    bestShare: (j['share'] as num?)?.toInt() ?? 0,
    bestTurns: (j['turns'] as num?)?.toInt() ?? 0,
    completedAt: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
  );
}

class Stats {
  const Stats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.localGames = 0,
    this.totalMoves = 0,
    this.totalCaptures = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.dailyCompleted = 0,
  });

  /// Games against the computer that reached an end.
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  /// Pass-and-play games (not counted as wins or losses).
  final int localGames;
  final int totalMoves;
  final int totalCaptures;
  final int currentStreak;
  final int bestStreak;
  final int dailyCompleted;

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  Stats copyWith({
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    int? localGames,
    int? totalMoves,
    int? totalCaptures,
    int? currentStreak,
    int? bestStreak,
    int? dailyCompleted,
  }) => Stats(
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
    draws: draws ?? this.draws,
    localGames: localGames ?? this.localGames,
    totalMoves: totalMoves ?? this.totalMoves,
    totalCaptures: totalCaptures ?? this.totalCaptures,
    currentStreak: currentStreak ?? this.currentStreak,
    bestStreak: bestStreak ?? this.bestStreak,
    dailyCompleted: dailyCompleted ?? this.dailyCompleted,
  );

  Map<String, Object> toJson() => {
    'played': gamesPlayed,
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'local': localGames,
    'moves': totalMoves,
    'captures': totalCaptures,
    'streak': currentStreak,
    'bestStreak': bestStreak,
    'daily': dailyCompleted,
  };

  static Stats fromJson(Map<String, dynamic> j) {
    int v(String k) => ((j[k] as num?)?.toInt() ?? 0).clamp(0, 1 << 40);
    return Stats(
      gamesPlayed: v('played'),
      wins: v('wins'),
      losses: v('losses'),
      draws: v('draws'),
      localGames: v('local'),
      totalMoves: v('moves'),
      totalCaptures: v('captures'),
      currentStreak: v('streak'),
      bestStreak: v('bestStreak'),
      dailyCompleted: v('daily'),
    );
  }
}

/// Everything the player has earned. Stored only on this device.
class Profile {
  const Profile({
    this.records = const {},
    this.stats = const Stats(),
    this.achievements = const {},
    this.installationId = '',
  });

  /// Keyed by level id: `"12"` for campaign, `"c4"` challenges, `"d20260921"`
  /// daily boards.
  final Map<String, LevelRecord> records;
  final Stats stats;

  /// Achievement id -> unlock time (ms since epoch).
  final Map<String, int> achievements;

  /// Random id generated on first launch. Never leaves the device; it only
  /// tags backup files.
  final String installationId;

  int starsFor(String id) => records[id]?.stars ?? 0;

  int get levelsCompleted =>
      records.entries.where((e) => int.tryParse(e.key) != null && e.value.completed).length;

  int get perfectLevels =>
      records.entries.where((e) => int.tryParse(e.key) != null && e.value.stars == 3).length;

  int get totalStars => records.entries
      .where((e) => int.tryParse(e.key) != null)
      .fold(0, (a, e) => a + e.value.stars);

  /// Highest campaign level completed (0 if none).
  int get bestLevel {
    var best = 0;
    for (final e in records.entries) {
      final n = int.tryParse(e.key);
      if (n != null && e.value.completed && n > best) best = n;
    }
    return best;
  }

  /// Levels unlock in order: the next one after the best completed.
  int get highestUnlocked => bestLevel + 1;

  bool isUnlocked(int level) => level <= highestUnlocked;

  Profile copyWith({
    Map<String, LevelRecord>? records,
    Stats? stats,
    Map<String, int>? achievements,
    String? installationId,
  }) => Profile(
    records: records ?? this.records,
    stats: stats ?? this.stats,
    achievements: achievements ?? this.achievements,
    installationId: installationId ?? this.installationId,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'installationId': installationId,
    'records': {for (final e in records.entries) e.key: e.value.toJson()},
    'stats': stats.toJson(),
    'achievements': achievements,
  };

  static Profile fromJson(Map<String, dynamic> j) {
    final recs = <String, LevelRecord>{};
    final raw = j['records'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map<String, dynamic>) recs[k.toString()] = LevelRecord.fromJson(v);
      });
    }
    final ach = <String, int>{};
    final rawAch = j['achievements'];
    if (rawAch is Map) {
      rawAch.forEach((k, v) {
        if (v is num) ach[k.toString()] = v.toInt();
      });
    }
    final stats = j['stats'];
    return Profile(
      records: recs,
      stats: stats is Map<String, dynamic> ? Stats.fromJson(stats) : const Stats(),
      achievements: ach,
      installationId: j['installationId'] as String? ?? '',
    );
  }
}
