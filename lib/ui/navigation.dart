import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/game_state.dart';
import '../engine/levels/level.dart';
import '../state/game_controller.dart';
import '../state/game_factory.dart';
import '../state/game_session.dart';
import '../state/providers.dart';
import 'screens/game_screen.dart';
import 'widgets/common.dart';

Route<T> fadeRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

/// Starts a new game, asking first if it would replace an unfinished one.
Future<void> launchGame(
  BuildContext context,
  WidgetRef ref,
  (GameConfig, GameState) game, {
  bool replaceRoute = false,
}) async {
  final saved = ref.read(savedGameProvider);
  if (saved != null && ref.read(gameProvider) == null) {
    final ok = await confirmDialog(
      context,
      title: 'Start a new game?',
      message: 'Your unfinished game (${saved.config.title}) will be discarded.',
      confirm: 'Start new',
      destructive: true,
    );
    if (ok != true || !context.mounted) return;
  }
  ref.read(gameProvider.notifier).start(game.$1, game.$2);
  final route = fadeRoute<void>(const GameScreen());
  if (replaceRoute) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
}

Future<void> launchLevel(BuildContext context, WidgetRef ref, LevelDef level, GameMode mode) =>
    launchGame(context, ref, levelGame(level, mode, ref.read(settingsProvider)));

Future<void> continueSavedGame(BuildContext context, WidgetRef ref) async {
  final saved = ref.read(savedGameProvider);
  if (saved == null) return;
  ref.read(gameProvider.notifier).resume(saved);
  await Navigator.of(context).push(fadeRoute<void>(const GameScreen()));
}
