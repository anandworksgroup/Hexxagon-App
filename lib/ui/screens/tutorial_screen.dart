import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/board_layout.dart';
import '../../engine/game_engine.dart';
import '../../engine/game_state.dart';
import '../../engine/hex.dart';
import '../../state/game_factory.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/hex_board.dart';

/// Five short cards with live mini-boards: tap, multiply, jump, capture,
/// dominate. Skippable, and shown only once automatically.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key, this.firstRun = false});
  final bool firstRun;

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _Page {
  const _Page(this.title, this.body, this.demo);
  final String title;
  final String body;
  final _Demo demo;
}

class _Demo {
  const _Demo(this.state, this.move, {this.selectOnly = false});
  final GameState state;
  final Move? move;
  final bool selectOnly;
}

GameState _board(int radius, List<Hex> mine, List<Hex> theirs) => GameEngine.newGame(
  layout: BoardLayout(hexagonCells(radius)),
  starts: [mine, theirs],
  humans: const [true, false],
);

Move _mv(GameState s, Hex from, Hex to, MoveType t) =>
    Move(s.layout.indexOf(from)!, s.layout.indexOf(to)!, t);

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _pages = PageController();
  int _index = 0;
  late final List<_Page> _content;

  @override
  void initState() {
    super.initState();
    final tap = _board(1, const [Hex.origin], const []);
    final multiply = _board(2, const [Hex(-1, 0)], const [Hex(2, -2)]);
    final jump = _board(2, const [Hex(-2, 1)], const [Hex(2, -2)]);
    final capture = _board(2, const [Hex(-1, 0)], const [Hex(1, 0), Hex(1, -1), Hex(0, 1), Hex(2, -1)]);
    final win = GameState(
      layout: BoardLayout(hexagonCells(2)),
      owners: const [0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1],
      playerCount: 2,
      current: 0,
      turn: 30,
      quietPlies: 0,
      humans: const [true, false],
    );
    _content = [
      _Page('Tap', 'This is your token. Tap it.', _Demo(tap, null, selectOnly: true)),
      _Page(
        'Multiply',
        'Move to a neighbouring hex to multiply. Your original token stays.',
        _Demo(multiply, _mv(multiply, const Hex(-1, 0), Hex.origin, MoveType.multiply)),
      ),
      _Page(
        'Jump',
        'Jump two hexes away to reposition. The old hex is left empty.',
        _Demo(jump, _mv(jump, const Hex(-2, 1), Hex.origin, MoveType.jump)),
      ),
      _Page(
        'Capture',
        'Land next to enemy tokens and every one of them becomes yours.',
        _Demo(capture, _mv(capture, const Hex(-1, 0), Hex.origin, MoveType.multiply)),
      ),
      _Page('Dominate', 'When the board fills up, whoever controls the most hexes wins.', _Demo(win, null)),
    ];
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _markSeen() =>
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(tutorialSeen: true));

  void _finish({bool play = false}) {
    _markSeen();
    if (!play) {
      Navigator.of(context).pop();
      return;
    }
    final level = ref.read(levelPackProvider).level(1)!;
    launchGame(
      context,
      ref,
      levelGame(level, GameMode.classic, ref.read(settingsProvider)),
      replaceRoute: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final last = _index == _content.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _finish(),
                    child: Text(widget.firstRun ? 'SKIP' : 'CLOSE', style: TextStyle(color: p.textSecondary)),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _content.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _TutorialPage(page: _content[i], active: i == _index),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _content.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? Theme.of(context).colorScheme.primary : p.boardEdge,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                  child: last
                      ? PrimaryButton(
                          label: widget.firstRun ? 'Play level 1' : 'Got it',
                          onPressed: () => _finish(play: widget.firstRun),
                        )
                      : PrimaryButton(
                          label: 'Next',
                          onPressed: () => _pages.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({required this.page, required this.active});
  final _Page page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(child: _DemoBoard(demo: page.demo, active: active)),
          const SizedBox(height: 18),
          Text(
            page.title.toUpperCase(),
            style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4),
          ),
          const SizedBox(height: 10),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Loops one demonstration move: select, show targets, play it, reset.
class _DemoBoard extends StatefulWidget {
  const _DemoBoard({required this.demo, required this.active});
  final _Demo demo;
  final bool active;

  @override
  State<_DemoBoard> createState() => _DemoBoardState();
}

class _DemoBoardState extends State<_DemoBoard> {
  Timer? _timer;
  int _step = 0;
  late GameState _state = widget.demo.state;
  MoveResult? _last;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _run();
  }

  @override
  void didUpdateWidget(_DemoBoard old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _run();
    if (!widget.active) _timer?.cancel();
  }

  void _run() {
    _timer?.cancel();
    _step = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final d = widget.demo;
    setState(() {
      _step = (_step + 1) % 5;
      if (_step == 0) {
        _state = d.state;
        _last = null;
      } else if (_step == 2 && d.move != null) {
        _last = GameEngine.apply(d.state, d.move!);
        _state = _last!.after;
        _serial++;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = widget.demo;
    final from = d.move?.from ?? (d.selectOnly ? d.state.layout.indexOf(Hex.origin) : null);
    final selecting = from != null && _step == 1 || (d.selectOnly && _step.isOdd);
    return Semantics(
      label: 'Demonstration board',
      excludeSemantics: true,
      child: HexBoard(
        state: _state,
        looks: [
          PlayerLook(color: p.player(0), token: 0, name: 'You'),
          PlayerLook(color: p.player(3), token: 2, name: 'Opponent'),
        ],
        selected: selecting ? from : null,
        targets: selecting && !d.selectOnly ? GameEngine.targetsFor(d.state, from!) : null,
        lastMove: _last,
        moveSerial: _serial,
        padding: 24,
      ),
    );
  }
}
