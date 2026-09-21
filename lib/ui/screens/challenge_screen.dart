import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/levels/level_generator.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/level_intro.dart';

class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final pack = ref.read(levelPackProvider);
    final profile = ref.watch(profileProvider);
    final today = ref.read(clockProvider)();
    final daily = LevelGenerator.daily(DateTime(today.year, today.month, today.day));
    final dailyStars = profile.starsFor(daily.id);
    final accent = Theme.of(context).colorScheme.primary;

    return MenuScaffold(
      title: 'Challenge',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Panel(
            onTap: () => showLevelIntro(context, ref, daily, GameMode.daily),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.today_rounded, color: p.symbol, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY CHALLENGE',
                        style: TextStyle(color: p.text, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${daily.name.replaceFirst('Daily · ', '')} · same board for everyone today',
                        style: TextStyle(color: p.textSecondary, fontSize: 13),
                      ),
                      if (dailyStars > 0) ...[
                        const SizedBox(height: 4),
                        StarRow(stars: dailyStars, size: 16),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textSecondary),
              ],
            ),
          ),
          const SectionLabel('Special boards'),
          for (var t = 0; t < LevelGenerator.challengeThemes.length; t++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LevelGenerator.challengeThemes[t].$1,
                            style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LevelGenerator.challengeThemes[t].$2,
                            style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    for (var r = 0; r < 3; r++)
                      Builder(
                        builder: (context) {
                          final c = pack.challenges[t * 3 + r];
                          final stars = profile.starsFor(c.id);
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Semantics(
                              button: true,
                              label: '${c.name}${stars > 0 ? ', $stars stars' : ''}',
                              excludeSemantics: true,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => showLevelIntro(context, ref, c, GameMode.challenge),
                                child: Container(
                                  width: 48,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: stars > 0 ? accent.withValues(alpha: 0.2) : p.surfaceHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        const ['I', 'II', 'III'][r],
                                        style: TextStyle(color: p.text, fontWeight: FontWeight.w900),
                                      ),
                                      if (stars > 0) StarRow(stars: stars, size: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
