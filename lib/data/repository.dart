import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../state/game_session.dart';
import 'local_store.dart';
import 'profile.dart';
import 'settings.dart';

/// All persistence in one place. Everything stays on the device: settings in
/// SharedPreferences, progress and the unfinished game as crash-safe JSON
/// files. There is no network code anywhere in the app.
class Repository {
  Repository(this._prefs, this._store);

  final SharedPreferences _prefs;
  final LocalStore _store;

  static const _settingsKey = 'settings.v1';
  static const _profileFile = 'profile';
  static const _gameFile = 'current_game';

  Settings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Settings();
    }
  }

  Future<void> saveSettings(Settings s) => _prefs.setString(_settingsKey, jsonEncode(s.toJson()));

  Profile loadProfile() {
    final raw = _store.read(_profileFile);
    var p = raw == null ? const Profile() : Profile.fromJson(raw);
    if (p.installationId.isEmpty) {
      p = p.copyWith(installationId: _newId());
      saveProfile(p);
    }
    return p;
  }

  Future<void> saveProfile(Profile p) => _store.write(_profileFile, p.toJson());

  /// Returns the unfinished game, or null if there is none or it is corrupt
  /// (a corrupt main file falls back to the backup copy first).
  SavedGame? loadSavedGame() {
    SavedGame? parsed;
    _store.read(
      _gameFile,
      validate: (j) {
        try {
          parsed = SavedGame.fromJson(j);
          return true;
        } catch (_) {
          return false;
        }
      },
    );
    return parsed;
  }

  Future<void> saveGame(SavedGame g) => _store.write(_gameFile, g.toJson());

  Future<void> clearSavedGame() => _store.delete(_gameFile);

  Future<void> flush() => _store.flush();

  // Backup ----------------------------------------------------------------

  Map<String, Object> exportBackup(Profile profile, Settings settings) => {
    'app': 'hexadominate',
    'format': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': profile.toJson(),
    'settings': settings.toJson(),
  };

  /// Parses a backup file. Throws [FormatException] if it is not one.
  (Profile, Settings) parseBackup(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('This file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'hexadominate') {
      throw const FormatException('This is not a HexaDominate backup.');
    }
    final profile = decoded['profile'];
    final settings = decoded['settings'];
    if (profile is! Map<String, dynamic>) {
      throw const FormatException('The backup has no progress data.');
    }
    return (
      Profile.fromJson(profile),
      settings is Map<String, dynamic> ? Settings.fromJson(settings) : const Settings(),
    );
  }

  static String _newId() {
    final r = math.Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
