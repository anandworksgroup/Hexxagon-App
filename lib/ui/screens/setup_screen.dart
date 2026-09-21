import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/levels/level_generator.dart';
import '../../engine/player.dart';
import '../../state/game_factory.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

enum SetupKind { aiBattle, quick, local }

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, required this.kind});
  final SetupKind kind;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  SkirmishBoard _board = SkirmishBoard.medium;
  int _opponents = 1;
  AiLevel _ai = AiLevel.normal;
  final _rng = math.Random();

  String get _title => switch (widget.kind) {
    SetupKind.aiBattle => 'AI Battle',
    SetupKind.quick => 'Quick Game',
    SetupKind.local => 'Local 2 Player',
  };

  void _start({bool surprise = false}) {
    final settings = ref.read(settingsProvider);
    final seed = _rng.nextInt(1 << 30);
    if (widget.kind == SetupKind.local) {
      launchGame(context, ref, localGame(board: _board, settings: settings, seed: seed));
      return;
    }
    var board = _board;
    var count = _opponents;
    var levels = List.filled(count, _ai);
    if (surprise) {
      board = SkirmishBoard.values[_rng.nextInt(SkirmishBoard.values.length)];
      count = 1 + _rng.nextInt(3);
      levels = List.generate(count, (_) => AiLevel.values[_rng.nextInt(3)]);
    }
    launchGame(
      context,
      ref,
      skirmishGame(
        mode: widget.kind == SetupKind.aiBattle ? GameMode.aiBattle : GameMode.quick,
        board: board,
        opponents: levels,
        settings: settings,
        seed: seed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final local = widget.kind == SetupKind.local;
    return MenuScaffold(
      title: _title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (!local) ...[
            const SectionLabel('Difficulty'),
            ChoiceRow<AiLevel>(
              values: AiLevel.values,
              selected: _ai,
              label: (a) => a.label,
              onChanged: (a) => setState(() => _ai = a),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(_describe(_ai), style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ),
            const SectionLabel('Opponents'),
            ChoiceRow<int>(
              values: const [1, 2, 3],
              selected: _opponents,
              label: (n) => n == 1 ? '1 AI' : '$n AI',
              onChanged: (n) => setState(() => _opponents = n),
            ),
          ],
          const SectionLabel('Board'),
          ChoiceRow<SkirmishBoard>(
            values: SkirmishBoard.values,
            selected: _board,
            label: (b) => b.label,
            onChanged: (b) => setState(() => _board = b),
          ),
          if (local)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                'Two players share this device and take turns. '
                'Turn the pass-the-device screen on or off in Settings.',
                style: TextStyle(color: p.textSecondary, height: 1.4),
              ),
            ),
          const SizedBox(height: 32),
          PrimaryButton(label: 'Start game', icon: Icons.play_arrow_rounded, onPressed: _start),
          if (widget.kind == SetupKind.quick) ...[
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Surprise me',
              icon: Icons.casino_rounded,
              onPressed: () => _start(surprise: true),
            ),
          ],
        ],
      ),
    );
  }

  static String _describe(AiLevel a) => switch (a) {
    AiLevel.easy => 'Grabs captures when it sees them. Good for learning.',
    AiLevel.normal => 'Weighs territory, captures and threats one move ahead.',
    AiLevel.hard => 'Searches several moves ahead with alpha-beta pruning.',
    AiLevel.expert => 'Deepest search and sharpest judgement. Takes a moment to think.',
  };
}
