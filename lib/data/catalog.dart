import 'profile.dart';

/// A token symbol the player can use. [unlockLevel] is the campaign level
/// that has to be completed first (0 = available from the start).
class TokenDef {
  const TokenDef(this.name, this.unlockLevel);
  final String name;
  final int unlockLevel;
}

/// Order matters: saved games and settings store the index.
const tokenCatalog = <TokenDef>[
  TokenDef('Classic', 0),
  TokenDef('Circle', 0),
  TokenDef('Star', 5),
  TokenDef('Diamond', 15),
  TokenDef('Triangle', 30),
  TokenDef('Heart', 50),
  TokenDef('Cross', 80),
  TokenDef('Hex', 120),
  TokenDef('Crown', 180),
  TokenDef('Lightning', 250),
];

const colorNames = ['Yellow', 'Purple', 'Orange', 'Blue', 'Green', 'Pink'];

bool isTokenUnlocked(int index, Profile p) =>
    index >= 0 && index < tokenCatalog.length && p.bestLevel >= tokenCatalog[index].unlockLevel;

int unlockedTokenCount(Profile p) =>
    [for (var i = 0; i < tokenCatalog.length; i++) i].where((i) => isTokenUnlocked(i, p)).length;

class AchievementDef {
  const AchievementDef(this.id, this.title, this.description, this.earned);
  final String id;
  final String title;
  final String description;
  final bool Function(Profile p, int levelCount) earned;
}

final achievementCatalog = <AchievementDef>[
  AchievementDef('first_win', 'First Victory', 'Win your first game', (p, _) => p.stats.wins >= 1),
  AchievementDef('conqueror', 'Conqueror', 'Complete 25 levels', (p, _) => p.levelsCompleted >= 25),
  AchievementDef('strategist', 'Strategist', 'Complete 50 levels', (p, _) => p.levelsCompleted >= 50),
  AchievementDef('master', 'Master', 'Complete 100 levels', (p, _) => p.levelsCompleted >= 100),
  AchievementDef(
    'legend',
    'Hex Legend',
    'Complete every level',
    (p, n) => n > 0 && p.levelsCompleted >= n,
  ),
  AchievementDef('perfect', 'Perfect', 'Earn 3 stars on a level', (p, _) => p.perfectLevels >= 1),
  AchievementDef(
    'perfectionist',
    'Perfectionist',
    'Earn 3 stars on 50 levels',
    (p, _) => p.perfectLevels >= 50,
  ),
  AchievementDef(
    'collector',
    'Collector',
    'Unlock all ${tokenCatalog.length} tokens',
    (p, _) => unlockedTokenCount(p) >= tokenCatalog.length,
  ),
  AchievementDef(
    'unstoppable',
    'Unstoppable',
    'Win 10 games in a row',
    (p, _) => p.stats.bestStreak >= 10,
  ),
  AchievementDef(
    'capturer',
    'Converter',
    'Capture 1,000 tokens',
    (p, _) => p.stats.totalCaptures >= 1000,
  ),
  AchievementDef(
    'daily',
    'Daily Devotion',
    'Win 7 daily challenges',
    (p, _) => p.stats.dailyCompleted >= 7,
  ),
  AchievementDef(
    'challenger',
    'Challenger',
    'Win 10 challenge boards',
    (p, _) => p.records.entries.where((e) => e.key.startsWith('c') && e.value.completed).length >= 10,
  ),
];
