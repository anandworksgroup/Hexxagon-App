import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final profile = ref.watch(profileProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final done = achievementCatalog.where((a) => profile.achievements.containsKey(a.id)).length;
    return MenuScaffold(
      title: 'Achievements',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              '$done of ${achievementCatalog.length} unlocked',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
          for (final a in achievementCatalog)
            Builder(
              builder: (context) {
                final at = profile.achievements[a.id];
                final unlocked = at != null;
                final date = unlocked ? DateTime.fromMillisecondsSinceEpoch(at) : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    label: '${a.title}. ${a.description}. ${unlocked ? 'Unlocked' : 'Locked'}',
                    excludeSemantics: true,
                    child: Panel(
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: unlocked ? accent : p.surfaceHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              unlocked ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                              color: unlocked ? p.symbol : p.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: TextStyle(
                                    color: unlocked ? p.text : p.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(a.description, style: TextStyle(color: p.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (date != null)
                            Text(
                              '${date.day}/${date.month}/${date.year}',
                              style: TextStyle(color: p.textSecondary, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
