import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/levels/level.dart';
import '../../state/game_factory.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../navigation.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'hex_board.dart';

/// Bottom sheet before a level: board preview, opponents, star goals.
Future<void> showLevelIntro(BuildContext context, WidgetRef ref, LevelDef level, GameMode mode) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheetContext) => _LevelIntro(level: level, mode: mode, outerContext: context),
  );
}

class _LevelIntro extends ConsumerWidget {
  const _LevelIntro({required this.level, required this.mode, required this.outerContext});
  final LevelDef level;
  final GameMode mode;
  final BuildContext outerContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final settings = ref.watch(settingsProvider);
    final best = ref.watch(profileProvider).starsFor(level.id);
    final (config, state) = levelGame(level, mode, settings);
    final looks = [
      for (final s in config.players)
        PlayerLook(color: p.player(s.colorIndex), token: s.tokenIndex, name: s.name),
    ];
    String pct(double v) => '${(v * 100).round()}%';
    final tier = level.tier;
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: p.boardEdge, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    level.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3),
                  ),
                  if (tier != null)
                    Text(
                      tier.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  if (best > 0) ...[
                    const SizedBox(height: 6),
                    Center(child: StarRow(stars: best, size: 18)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: (height * 0.3).clamp(160.0, 300.0),
                    child: IgnorePointer(
                      child: HexBoard(state: state, looks: looks, style: settings.boardStyle, animate: false),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _Fact(icon: Icons.hexagon_outlined, text: '${level.cells.length} hexes'),
                      _Fact(
                        icon: Icons.smart_toy_outlined,
                        text: level.opponents.length == 1
                            ? level.opponents.first.label
                            : '${level.opponents.length} × ${{for (final a in level.opponents) a.label}.join('/')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _Goal(stars: 1, text: 'Win the game'),
                        _Goal(stars: 2, text: 'Win holding ${pct(level.twoStarShare)} of the tokens'),
                        _Goal(stars: 3, text: 'Win holding ${pct(level.threeStarShare)} without undo'),
                      ],
                    ),
                  ),
                  if (level.tip != null) ...[
                    const SizedBox(height: 12),
                    Text(level.tip!, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, height: 1.35)),
                  ],
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Play',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      launchLevel(outerContext, ref, level, mode);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: p.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.stars, required this.text});
  final int stars;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 54, child: StarRow(stars: stars, size: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: context.palette.text))),
      ],
    ),
  );
}
