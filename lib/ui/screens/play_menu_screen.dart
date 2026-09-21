import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'challenge_screen.dart';
import 'level_select_screen.dart';
import 'setup_screen.dart';

class PlayMenuScreen extends ConsumerWidget {
  const PlayMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final total = ref.read(levelPackProvider).levels.length;
    void open(Widget page) => Navigator.of(context).push(fadeRoute<void>(page));
    return MenuScaffold(
      title: 'Play',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ModeCard(
            icon: Icons.hexagon_rounded,
            title: 'Classic',
            subtitle: 'Level ${profile.highestUnlocked.clamp(1, total)} of $total · ${profile.totalStars} stars',
            onTap: () => open(const LevelSelectScreen()),
          ),
          _ModeCard(
            icon: Icons.smart_toy_rounded,
            title: 'AI Battle',
            subtitle: 'Pick a difficulty from Easy to Expert',
            onTap: () => open(const SetupScreen(kind: SetupKind.aiBattle)),
          ),
          _ModeCard(
            icon: Icons.emoji_events_rounded,
            title: 'Challenge',
            subtitle: 'Daily board and 30 special layouts',
            onTap: () => open(const ChallengeScreen()),
          ),
          _ModeCard(
            icon: Icons.bolt_rounded,
            title: 'Quick Game',
            subtitle: 'Choose a board and opponents, or be surprised',
            onTap: () => open(const SetupScreen(kind: SetupKind.quick)),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: p.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}
