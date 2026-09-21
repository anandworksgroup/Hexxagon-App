import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'screens/home_screen.dart';
import 'screens/tutorial_screen.dart';
import 'theme/app_theme.dart';

class HexaApp extends ConsumerStatefulWidget {
  const HexaApp({super.key});

  @override
  ConsumerState<HexaApp> createState() => _HexaAppState();
}

class _HexaAppState extends ConsumerState<HexaApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // First launch: offer the short tutorial on top of Home (skippable).
    if (!ref.read(settingsProvider).tutorialSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigator.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => const TutorialScreen(firstRun: true)),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Music only plays while the app is visible. Games are saved after
    // every move, so there is nothing else to do when backgrounded.
    ref.read(feedbackProvider).setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'HexaDominate',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(settings),
      navigatorKey: _navigator,
      home: const HomeScreen(),
    );
  }
}
