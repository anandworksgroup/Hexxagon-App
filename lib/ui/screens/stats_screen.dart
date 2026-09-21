import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static String _n(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final s = profile.stats;
    final rows = <(String, String)>[
      ('Games played', _n(s.gamesPlayed)),
      ('Wins', _n(s.wins)),
      ('Losses', _n(s.losses)),
      ('Draws', _n(s.draws)),
      ('Win rate', '${(s.winRate * 100).round()}%'),
      ('Levels completed', _n(profile.levelsCompleted)),
      ('Perfect levels', _n(profile.perfectLevels)),
      ('Best level', profile.bestLevel == 0 ? '–' : '${profile.bestLevel}'),
      ('Total stars', _n(profile.totalStars)),
      ('Total captures', _n(s.totalCaptures)),
      ('Total moves', _n(s.totalMoves)),
      ('Current win streak', _n(s.currentStreak)),
      ('Best win streak', _n(s.bestStreak)),
      ('Daily challenges won', _n(s.dailyCompleted)),
      ('Local 2-player games', _n(s.localGames)),
    ];
    final p = context.palette;
    return MenuScaffold(
      title: 'Statistics',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.boardEdge.withValues(alpha: 0.6)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        Expanded(child: Text(rows[i].$1, style: TextStyle(color: p.textSecondary, fontSize: 15))),
                        Text(
                          rows[i].$2,
                          style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Statistics are kept only on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
