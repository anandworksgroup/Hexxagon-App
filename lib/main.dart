import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_store.dart';
import 'data/repository.dart';
import 'data/settings.dart';
import 'engine/levels/level.dart';
import 'state/providers.dart';
import 'ui/app.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const Bootstrap());
}

/// Shows the splash while local storage and the level pack load, then hands
/// over to the real app. Nothing here touches the network.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  List<Override>? _overrides;
  Settings _settings = const Settings();
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final started = DateTime.now();
    try {
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        getApplicationSupportDirectory(),
        rootBundle.loadString('assets/levels/levels.json'),
      ]);
      final prefs = results[0] as SharedPreferences;
      final dir = Directory('${(results[1] as Directory).path}${Platform.pathSeparator}data');
      final pack = LevelPack.fromJson(jsonDecode(results[2] as String) as Map<String, dynamic>);
      final repo = Repository(prefs, LocalStore(dir));
      _settings = repo.loadSettings();
      // Keep the splash up briefly so it doesn't flash, but never > ~1s.
      final elapsed = DateTime.now().difference(started);
      const minSplash = Duration(milliseconds: 600);
      if (elapsed < minSplash) await Future<void>.delayed(minSplash - elapsed);
      if (!mounted) return;
      setState(() {
        _overrides = [
          repositoryProvider.overrideWithValue(repo),
          levelPackProvider.overrideWithValue(pack),
        ];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overrides = _overrides;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: overrides == null
          ? MaterialApp(
              key: const ValueKey('splash'),
              debugShowCheckedModeBanner: false,
              theme: buildTheme(_settings),
              home: SplashScreen(error: _error),
            )
          : ProviderScope(
              key: const ValueKey('app'),
              overrides: overrides,
              child: const HexaApp(),
            ),
    );
  }
}
