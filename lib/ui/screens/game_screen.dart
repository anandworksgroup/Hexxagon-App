import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/levels/level.dart';
import '../../state/game_controller.dart';
import '../../state/game_factory.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/hex_board.dart';
import '../widgets/token_painter.dart';
import 'settings_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _showResult = false;
  Timer? _resultTimer;

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  GameController get _game => ref.read(gameProvider.notifier);

  List<PlayerLook> _looks(GameView v, Palette p) => [
    for (final s in v.config.players)
      PlayerLook(color: p.player(s.colorIndex), token: s.tokenIndex, name: s.name),
  ];

  void _goHome() {
    _game.leave();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _pause() async {
    final v = ref.read(gameProvider);
    if (v == null) return;
    if (v.phase == GamePhase.over) {
      _goHome();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => const _PauseDialog(),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restart':
        final ok = await confirmDialog(
          context,
          title: 'Restart?',
          message: 'This game will start again from the beginning.',
          confirm: 'Restart',
        );
        if (ok == true) _game.restart();
      case 'settings':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      case 'exit':
        await _exit();
    }
  }

  Future<void> _exit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this game?'),
        content: const Text('A saved game can be picked up again from Continue on the home screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'quit'),
            child: Text('QUIT', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('SAVE & EXIT'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      _goHome();
    } else if (choice == 'quit') {
      _game.leave(discard: true);
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(gameProvider);
    final settings = ref.watch(settingsProvider);
    final palette = context.palette;

    ref.listen(gameProvider.select((v) => v?.noticeSerial), (prev, next) {
      final notice = ref.read(gameProvider)?.notice;
      if (prev != null && next != prev && notice != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice), duration: const Duration(seconds: 2)));
      }
    });
    ref.listen(gameProvider.select((v) => v?.phase), (prev, next) {
      _resultTimer?.cancel();
      if (next == GamePhase.over) {
        _resultTimer = Timer(const Duration(milliseconds: 750), () {
          if (mounted) setState(() => _showResult = true);
        });
      } else if (_showResult) {
        setState(() => _showResult = false);
      }
    });

    if (view == null) return Scaffold(backgroundColor: palette.background);

    final looks = _looks(view, palette);
    final level = levelFor(ref.read(levelPackProvider), view.config);
    final tutorialLevel = view.config.levelNumber != null && view.config.levelNumber! <= 10;
    final showHints = settings.showHints || tutorialLevel;

    final board = HexBoard(
      state: view.state,
      looks: looks,
      selected: view.selected,
      targets: showHints ? view.targets : null,
      pending: view.pending,
      lastMove: view.lastMove,
      moveSerial: view.moveSerial,
      animate: settings.animations,
      style: settings.boardStyle,
      onTap: view.phase == GamePhase.human ? _game.tap : null,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final landscape = box.maxWidth > box.maxHeight * 1.2;
                  return landscape
                      ? _landscape(view, looks, board, level, tutorialLevel)
                      : _portrait(view, looks, board, level, tutorialLevel);
                },
              ),
              if (view.phase == GamePhase.passDevice) _PassDevice(view: view, looks: looks),
              if (_showResult && view.outcome != null)
                _ResultOverlay(
                  view: view,
                  looks: looks,
                  onHome: _goHome,
                  onReplay: _game.restart,
                  onNext: _nextLevel,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextLevel() {
    final v = ref.read(gameProvider);
    final n = v?.config.levelNumber;
    if (n == null) return;
    final next = ref.read(levelPackProvider).level(n + 1);
    if (next == null) return;
    final game = levelGame(next, GameMode.classic, ref.read(settingsProvider));
    _game.start(game.$1, game.$2);
  }

  Widget _header(GameView v, {bool compact = false}) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Pause',
            onPressed: _pause,
            icon: const Icon(Icons.pause_rounded),
            iconSize: 28,
          ),
          Expanded(
            child: Text(
              v.config.title.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          if (v.config.undoAllowed)
            IconButton(
              tooltip: 'Undo',
              onPressed: v.canUndo ? _game.undo : null,
              icon: const Icon(Icons.undo_rounded),
              iconSize: 26,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _portrait(GameView v, List<PlayerLook> looks, Widget board, LevelDef? level, bool tutorial) {
    return Column(
      children: [
        _header(v),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Scores(view: v, looks: looks, vertical: false),
        ),
        if (level != null) _Goals(level: level, usedUndo: v.usedUndo),
        Expanded(
          child: Padding(padding: const EdgeInsets.all(8), child: board),
        ),
        _BottomBar(view: v, looks: looks, level: level, tutorial: tutorial),
      ],
    );
  }

  Widget _landscape(GameView v, List<PlayerLook> looks, Widget board, LevelDef? level, bool tutorial) {
    return Row(
      children: [
        SizedBox(
          width: 230,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(v, compact: true),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _Scores(view: v, looks: looks, vertical: true),
                      if (level != null) _Goals(level: level, usedUndo: v.usedUndo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: board)),
        SizedBox(
          width: 230,
          child: Center(
            child: _BottomBar(view: v, looks: looks, level: level, tutorial: tutorial),
          ),
        ),
      ],
    );
  }
}

class _Scores extends StatelessWidget {
  const _Scores({required this.view, required this.looks, required this.vertical});
  final GameView view;
  final List<PlayerLook> looks;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final counts = view.state.counts;
    final n = counts.length;
    final chips = [
      for (var i = 0; i < n; i++)
        _ScoreChip(
          look: looks[i],
          count: counts[i],
          active: !view.state.isOver && view.state.current == i,
          out: counts[i] == 0,
          big: n <= 2,
          symbolColor: p.symbol,
        ),
    ];
    if (vertical) {
      return Column(
        children: [
          for (final c in chips) Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
        ],
      );
    }
    return Row(
      mainAxisAlignment: n <= 2 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceEvenly,
      children: [for (final c in chips) Flexible(child: c)],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.look,
    required this.count,
    required this.active,
    required this.out,
    required this.big,
    required this.symbolColor,
  });

  final PlayerLook look;
  final int count;
  final bool active;
  final bool out;
  final bool big;
  final Color symbolColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '${look.name}: $count hexes${active ? ', current turn' : ''}${out ? ', eliminated' : ''}',
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: out ? 0.35 : (active ? 1 : 0.7),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TokenIcon(color: look.color, token: look.token, symbolColor: symbolColor, size: big ? 30 : 24),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: p.text,
                      fontSize: big ? 28 : 22,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 3,
                width: active ? (big ? 64 : 48) : 0,
                decoration: BoxDecoration(color: look.color, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Goals extends StatelessWidget {
  const _Goals({required this.level, required this.usedUndo});
  final LevelDef level;
  final bool usedUndo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = TextStyle(color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w700);
    String pct(double v) => '${(v * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [const StarRow(stars: 1, max: 1, size: 13), Text(' Win', style: style)]),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [const StarRow(stars: 2, max: 2, size: 13), Text(' ${pct(level.twoStarShare)}', style: style)],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StarRow(stars: usedUndo ? 0 : 3, max: 3, size: 13),
              Text(
                usedUndo ? ' used undo' : ' ${pct(level.threeStarShare)} no undo',
                style: style,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.view, required this.looks, required this.level, required this.tutorial});
  final GameView view;
  final List<PlayerLook> looks;
  final LevelDef? level;
  final bool tutorial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final game = ref.read(gameProvider.notifier);
    final s = view.state;
    final cur = view.config.players[s.current];
    final look = looks[s.current];
    final singleHuman = view.config.players.where((x) => x.isHuman).length == 1;

    Widget status;
    if (view.phase == GamePhase.over) {
      status = _statusText('GAME OVER', p.text);
    } else if (!cur.isHuman) {
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TokenIcon(color: look.color, token: look.token, symbolColor: p.symbol, size: 18),
          const SizedBox(width: 8),
          Flexible(child: _statusText('${cur.name.toUpperCase()} THINKING', p.textSecondary)),
          const SizedBox(width: 8),
          ThinkingDots(color: look.color),
        ],
      );
    } else {
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!singleHuman) ...[
            TokenIcon(color: look.color, token: look.token, symbolColor: p.symbol, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: _statusText(singleHuman ? 'YOUR TURN' : '${cur.name.toUpperCase()} TURN', look.color),
          ),
        ],
      );
    }

    // Short coaching for tutorial levels and level tips at the start.
    String? coach;
    if (view.phase == GamePhase.human && cur.isHuman) {
      if (tutorial && view.selected == null && s.turn < 6) {
        coach = 'Tap one of your tokens';
      } else if (tutorial && view.selected != null && s.turn < 6) {
        coach = 'Tap a highlighted hex: next to it multiplies, two away jumps';
      }
    }
    // Kept for the whole game so the board never jumps when it goes away.
    final tip = view.phase == GamePhase.over ? null : level?.tip;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tip != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: p.player(0), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tip, style: TextStyle(color: p.text, fontSize: 13, height: 1.3))),
                  ],
                ),
              ),
            ),
          if (view.pending != null)
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'Cancel', onPressed: game.cancelPending, height: 48)),
                const SizedBox(width: 10),
                Expanded(child: PrimaryButton(label: 'Confirm', onPressed: game.confirmPending, height: 48)),
              ],
            )
          else ...[
            SizedBox(height: 28, child: Center(child: status)),
            if (coach != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  coach,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusText(String text, Color color) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2),
  );
}

class _PauseDialog extends StatelessWidget {
  const _PauseDialog();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PAUSED',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 10),
            SecondaryButton(label: 'Restart', icon: Icons.replay_rounded, onPressed: () => Navigator.pop(context, 'restart')),
            const SizedBox(height: 10),
            SecondaryButton(label: 'Settings', icon: Icons.tune_rounded, onPressed: () => Navigator.pop(context, 'settings')),
            const SizedBox(height: 10),
            SecondaryButton(label: 'Exit game', icon: Icons.logout_rounded, onPressed: () => Navigator.pop(context, 'exit')),
          ],
        ),
      ),
    );
  }
}

class _PassDevice extends ConsumerWidget {
  const _PassDevice({required this.view, required this.looks});
  final GameView view;
  final List<PlayerLook> looks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final look = looks[view.state.current];
    return Positioned.fill(
      child: ColoredBox(
        color: p.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TokenIcon(color: look.color, token: look.token, symbolColor: p.symbol, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    '${look.name.toUpperCase()} TURN',
                    style: TextStyle(color: look.color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
                  ),
                  const SizedBox(height: 10),
                  Text('Pass the device', style: TextStyle(color: p.textSecondary, fontSize: 16)),
                  const SizedBox(height: 32),
                  PrimaryButton(label: 'Ready', onPressed: ref.read(gameProvider.notifier).passDeviceReady),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.view,
    required this.looks,
    required this.onHome,
    required this.onReplay,
    required this.onNext,
  });

  final GameView view;
  final List<PlayerLook> looks;
  final VoidCallback onHome;
  final VoidCallback onReplay;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final o = view.outcome!;
    final config = view.config;
    final local = config.mode.isLocal;
    final humanSeat = config.players.indexWhere((x) => x.isHuman);

    String headline;
    Color headColor = p.text;
    if (o.isDraw && (local || o.winners.contains(humanSeat))) {
      headline = 'DRAW';
    } else if (local) {
      final w = o.winners.first;
      headline = '${looks[w].name.toUpperCase()} WINS';
      headColor = looks[w].color;
    } else {
      headline = o.won ? 'YOU WIN' : 'YOU LOST';
      headColor = o.won ? looks[humanSeat].color : p.text;
    }
    final trophy = local ? !o.isDraw : o.won;

    final order = List<int>.generate(o.counts.length, (i) => i)
      ..sort((a, b) => o.counts[b].compareTo(o.counts[a]));
    final hasLevel = config.mode.hasLevel;

    final buttons = <Widget>[];
    if (o.hasNextLevel) {
      buttons.add(PrimaryButton(label: 'Next level', icon: Icons.arrow_forward_rounded, onPressed: onNext));
      buttons.add(SecondaryButton(label: 'Replay', onPressed: onReplay));
    } else if (!o.won && !local && !o.isDraw) {
      buttons.add(PrimaryButton(label: 'Retry', icon: Icons.replay_rounded, onPressed: onReplay));
    } else {
      buttons.add(PrimaryButton(label: 'Replay', icon: Icons.replay_rounded, onPressed: onReplay));
    }
    buttons.add(SecondaryButton(label: 'Home', icon: Icons.home_rounded, onPressed: onHome));

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => ColoredBox(
          color: p.background.withValues(alpha: 0.86 * t),
          child: Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(26),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'GAME OVER',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3),
                      ),
                      const SizedBox(height: 12),
                      if (trophy)
                        Icon(Icons.emoji_events_rounded, size: 64, color: headColor)
                      else
                        Icon(
                          o.isDraw ? Icons.balance_rounded : Icons.flag_rounded,
                          size: 56,
                          color: p.textSecondary,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: headColor, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3),
                      ),
                      if (hasLevel && o.won) ...[
                        const SizedBox(height: 10),
                        Center(child: _AnimatedStars(stars: o.stars)),
                        if (o.stars > o.previousStars && o.previousStars > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'New best!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                      if (o.isDraw)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Top players each hold ${o.counts[o.winners.first]} hexes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.textSecondary),
                          ),
                        ),
                      const SizedBox(height: 18),
                      for (final i in order)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              TokenIcon(color: looks[i].color, token: looks[i].token, symbolColor: p.symbol, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  i == humanSeat && !local ? 'Your territory' : looks[i].name,
                                  style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${o.counts[i]}',
                                style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      for (final t in o.newTokens)
                        _Unlock(icon: Icons.hexagon_outlined, text: 'New token unlocked: ${t.name}'),
                      for (final a in o.newAchievements)
                        _Unlock(icon: Icons.military_tech_rounded, text: 'Achievement: ${a.title}'),
                      const SizedBox(height: 20),
                      for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Unlock extends StatelessWidget {
  const _Unlock({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: p.text, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _AnimatedStars extends StatelessWidget {
  const _AnimatedStars({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$stars of 3 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 380 + i * 180),
              curve: Interval(i * 0.25, 1, curve: Curves.easeOutBack),
              builder: (context, t, _) => Transform.scale(
                scale: i < stars ? t : 1,
                child: Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 44,
                  color: i < stars ? const Color(0xFFF7C948) : p.textSecondary.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
