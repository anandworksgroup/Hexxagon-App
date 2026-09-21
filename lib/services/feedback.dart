import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data/settings.dart';

enum Sfx { tick, move, capture, success, failure, achievement }

/// Sound effects, background music and haptics, all from bundled assets.
/// Every call is fire-and-forget and swallows platform errors: feedback must
/// never break a game.
class FeedbackService {
  FeedbackService();

  Settings _settings = const Settings();
  final Map<Sfx, AudioPlayer> _players = {};
  AudioPlayer? _music;
  bool _musicPlaying = false;
  bool _inForeground = true;

  static final _context = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  void apply(Settings s) {
    _settings = s;
    _syncMusic();
  }

  void setForeground(bool foreground) {
    _inForeground = foreground;
    _syncMusic();
  }

  Future<void> play(Sfx sfx) async {
    if (!_settings.sound) return;
    try {
      final p = _players[sfx] ??= AudioPlayer()
        ..setAudioContext(_context)
        ..setPlayerMode(PlayerMode.lowLatency)
        ..setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource('sounds/${sfx.name}.wav'), volume: 0.6);
    } catch (_) {}
  }

  void _syncMusic() {
    final want = _settings.music && _inForeground;
    if (want == _musicPlaying) return;
    _musicPlaying = want;
    unawaited(_applyMusic(want));
  }

  Future<void> _applyMusic(bool on) async {
    try {
      if (on) {
        final m = _music ??= AudioPlayer()
          ..setAudioContext(_context)
          ..setReleaseMode(ReleaseMode.loop);
        await m.play(AssetSource('sounds/music.wav'), volume: 0.22);
      } else {
        await _music?.pause();
      }
    } catch (_) {}
  }

  // Haptics ---------------------------------------------------------------

  void select() {
    if (_settings.haptics) HapticFeedback.lightImpact();
  }

  void move() {
    if (_settings.haptics) HapticFeedback.mediumImpact();
  }

  void capture() {
    if (!_settings.haptics) return;
    HapticFeedback.selectionClick();
    Future.delayed(const Duration(milliseconds: 70), HapticFeedback.selectionClick);
    Future.delayed(const Duration(milliseconds: 140), HapticFeedback.selectionClick);
  }

  void win() {
    if (!_settings.haptics) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 120), HapticFeedback.lightImpact);
    Future.delayed(const Duration(milliseconds: 260), HapticFeedback.heavyImpact);
  }
}
