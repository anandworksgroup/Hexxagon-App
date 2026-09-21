import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile.dart';
import '../../engine/levels/level.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/hex_board.dart';
import '../widgets/level_intro.dart';

class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.read(levelPackProvider);
    final profile = ref.watch(profileProvider);
    final current = profile.highestUnlocked.clamp(1, pack.levels.length);
    final tiers = LevelTier.values;
    final initialTab = tiers.indexOf(LevelTier.of(current));
    return DefaultTabController(
      length: tiers.length,
      initialIndex: initialTab,
      child: MenuScaffold(
        title: 'Levels',
        maxWidth: 900,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: context.palette.text,
          unselectedLabelColor: context.palette.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
          tabs: [
            for (final t in tiers)
              Tab(text: '${t.label.toUpperCase()}${profile.isUnlocked(t.first) ? '' : '  🔒'}'),
          ],
        ),
        child: TabBarView(
          children: [
            for (final t in tiers)
              _TierGrid(
                tier: t,
                levels: pack.levels.sublist(t.first - 1, math.min(t.last, pack.levels.length)),
                profile: profile,
                current: current,
              ),
          ],
        ),
      ),
    );
  }
}

class _TierGrid extends ConsumerStatefulWidget {
  const _TierGrid({required this.tier, required this.levels, required this.profile, required this.current});
  final LevelTier tier;
  final List<LevelDef> levels;
  final Profile profile;
  final int current;

  @override
  ConsumerState<_TierGrid> createState() => _TierGridState();
}

class _TierGridState extends ConsumerState<_TierGrid> {
  final _scroll = ScrollController();
  static const _extent = 84.0;

  @override
  void initState() {
    super.initState();
    // Bring the current level into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final idx = widget.current - widget.tier.first;
      if (idx < 0 || idx >= widget.levels.length) return;
      final viewport = _scroll.position.viewportDimension;
      final box = context.size;
      final cols = math.max(1, ((box?.width ?? 360) - 32) ~/ _extent);
      final row = idx ~/ cols;
      final target = (row * _extent - viewport / 3).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stars = widget.levels.fold<int>(0, (a, l) => a + widget.profile.starsFor(l.id));
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Text(
                  'Levels ${widget.tier.first}–${widget.tier.last}',
                  style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF7C948)),
                const SizedBox(width: 4),
                Text(
                  '$stars / ${widget.levels.length * 3}',
                  style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _extent,
              mainAxisExtent: _extent,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final level = widget.levels[i];
                final n = level.number!;
                return LevelTile(
                  number: n,
                  stars: widget.profile.starsFor(level.id),
                  locked: !widget.profile.isUnlocked(n),
                  current: n == widget.current,
                  onTap: () => showLevelIntro(context, ref, level, GameMode.classic),
                );
              },
              childCount: widget.levels.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// A level on the map: a hexagon with its number and stars.
class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.number,
    required this.stars,
    required this.locked,
    required this.current,
    required this.onTap,
  });

  final int number;
  final int stars;
  final bool locked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = Theme.of(context).colorScheme.primary;
    final fill = current
        ? accent
        : stars == 3
        ? Color.lerp(p.board, const Color(0xFFF7C948), 0.22)!
        : p.board;
    final label = locked
        ? 'Level $number, locked'
        : 'Level $number${stars > 0 ? ', $stars stars' : current ? ', next to play' : ''}';
    return Semantics(
      button: !locked,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: CustomPaint(
          painter: _HexTilePainter(fill: fill, edge: current ? accent : p.boardEdge, dim: locked),
          child: Center(
            child: locked
                ? Icon(Icons.lock_rounded, size: 18, color: p.textSecondary.withValues(alpha: 0.6))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$number',
                        style: TextStyle(
                          color: current ? p.symbol : p.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (stars > 0) StarRow(stars: stars, size: 11)
                      else if (!current) const SizedBox(height: 11),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _HexTilePainter extends CustomPainter {
  _HexTilePainter({required this.fill, required this.edge, required this.dim});
  final Color fill;
  final Color edge;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.98;
    final path = BoardGeometry.hexPath(r).shift(size.center(Offset.zero));
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: dim ? 0.45 : 1));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = edge.withValues(alpha: dim ? 0.5 : 1),
    );
  }

  @override
  bool shouldRepaint(_HexTilePainter old) => old.fill != fill || old.edge != edge || old.dim != dim;
}
