import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'achievements_screen.dart';
import 'level_select_screen.dart';
import 'play_menu_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'stats_screen.dart';
import 'tokens_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final saved = ref.watch(savedGameProvider);
    final profile = ref.watch(profileProvider);
    void open(Widget page) => Navigator.of(context).push(fadeRoute<void>(page));

    final menu = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saved != null) ...[
          PrimaryButton(
            label: 'Continue',
            subtitle: saved.config.title,
            icon: Icons.play_arrow_rounded,
            height: 64,
            onPressed: () => continueSavedGame(context, ref),
          ),
          const SizedBox(height: 12),
        ],
        saved == null
            ? PrimaryButton(label: 'Play', height: 64, onPressed: () => open(const PlayMenuScreen()))
            : SecondaryButton(label: 'Play', height: 60, onPressed: () => open(const PlayMenuScreen())),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Levels',
                icon: Icons.hexagon_outlined,
                onPressed: () => open(const LevelSelectScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: '2 Player',
                icon: Icons.people_alt_rounded,
                onPressed: () => open(const SetupScreen(kind: SetupKind.local)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _IconAction(icon: Icons.category_rounded, label: 'Tokens', onTap: () => open(const TokensScreen())),
            _IconAction(icon: Icons.bar_chart_rounded, label: 'Statistics', onTap: () => open(const StatsScreen())),
            _IconAction(
              icon: Icons.military_tech_rounded,
              label: 'Achievements',
              onTap: () => open(const AchievementsScreen()),
            ),
            _IconAction(icon: Icons.settings_rounded, label: 'Settings', onTap: () => open(const SettingsScreen())),
          ],
        ),
      ],
    );

    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HexLogo(size: 104),
        const SizedBox(height: 20),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'HEXADOMINATE',
            style: TextStyle(color: p.text, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 5),
          ),
        ),
        const SizedBox(height: 6),
        Text('Conquer every hex.', style: TextStyle(color: p.textSecondary, fontSize: 15)),
        if (profile.bestLevel > 0) ...[
          const SizedBox(height: 14),
          Text(
            'Level ${profile.highestUnlocked.clamp(1, ref.read(levelPackProvider).levels.length)} · '
            '${profile.totalStars} ★',
            style: TextStyle(color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight * 1.2;
            if (landscape) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: title),
                      const SizedBox(width: 48),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: menu),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, const SizedBox(height: 44), menu],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: p.textSecondary, size: 26),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
