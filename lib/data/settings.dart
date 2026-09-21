enum AppThemeKind {
  dark('Dark'),
  light('Light'),
  midnight('Midnight'),
  oled('OLED');

  const AppThemeKind(this.label);
  final String label;
}

enum BoardStyle {
  flat('Flat'),
  outline('Outline'),
  raised('Raised');

  const BoardStyle(this.label);
  final String label;
}

enum AiSpeed {
  slow('Slow', 1.5),
  normal('Normal', 1),
  fast('Fast', 0.5);

  const AiSpeed(this.label, this.factor);
  final String label;

  /// Multiplies the AI's minimum "thinking" pause and move animations.
  final double factor;
}

class Settings {
  const Settings({
    this.sound = true,
    this.music = true,
    this.haptics = true,
    this.theme = AppThemeKind.dark,
    this.boardStyle = BoardStyle.flat,
    this.animations = true,
    this.aiSpeed = AiSpeed.normal,
    this.showHints = true,
    this.confirmMove = false,
    this.passDevice = true,
    this.highContrast = false,
    this.language = 'en',
    this.playerColor = 0,
    this.playerToken = 0,
    this.tutorialSeen = false,
  });

  final bool sound;
  final bool music;
  final bool haptics;
  final AppThemeKind theme;
  final BoardStyle boardStyle;
  final bool animations;
  final AiSpeed aiSpeed;

  /// Highlight legal destinations after selecting a token.
  final bool showHints;

  /// Require a second tap to confirm each move.
  final bool confirmMove;

  /// Show a "pass the device" screen between turns in local games.
  final bool passDevice;
  final bool highContrast;
  final String language;
  final int playerColor;
  final int playerToken;
  final bool tutorialSeen;

  Settings copyWith({
    bool? sound,
    bool? music,
    bool? haptics,
    AppThemeKind? theme,
    BoardStyle? boardStyle,
    bool? animations,
    AiSpeed? aiSpeed,
    bool? showHints,
    bool? confirmMove,
    bool? passDevice,
    bool? highContrast,
    String? language,
    int? playerColor,
    int? playerToken,
    bool? tutorialSeen,
  }) => Settings(
    sound: sound ?? this.sound,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    theme: theme ?? this.theme,
    boardStyle: boardStyle ?? this.boardStyle,
    animations: animations ?? this.animations,
    aiSpeed: aiSpeed ?? this.aiSpeed,
    showHints: showHints ?? this.showHints,
    confirmMove: confirmMove ?? this.confirmMove,
    passDevice: passDevice ?? this.passDevice,
    highContrast: highContrast ?? this.highContrast,
    language: language ?? this.language,
    playerColor: playerColor ?? this.playerColor,
    playerToken: playerToken ?? this.playerToken,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
  );

  Map<String, Object> toJson() => {
    'sound': sound,
    'music': music,
    'haptics': haptics,
    'theme': theme.name,
    'boardStyle': boardStyle.name,
    'animations': animations,
    'aiSpeed': aiSpeed.name,
    'showHints': showHints,
    'confirmMove': confirmMove,
    'passDevice': passDevice,
    'highContrast': highContrast,
    'language': language,
    'playerColor': playerColor,
    'playerToken': playerToken,
    'tutorialSeen': tutorialSeen,
  };

  /// Lenient: unknown or missing keys fall back to defaults one by one.
  static Settings fromJson(Map<String, dynamic> j) {
    const d = Settings();
    T pick<T>(String key, T fallback) {
      final v = j[key];
      return v is T ? v : fallback;
    }

    E pickEnum<E extends Enum>(List<E> values, String key, E fallback) {
      final v = j[key];
      for (final e in values) {
        if (e.name == v) return e;
      }
      return fallback;
    }

    return Settings(
      sound: pick('sound', d.sound),
      music: pick('music', d.music),
      haptics: pick('haptics', d.haptics),
      theme: pickEnum(AppThemeKind.values, 'theme', d.theme),
      boardStyle: pickEnum(BoardStyle.values, 'boardStyle', d.boardStyle),
      animations: pick('animations', d.animations),
      aiSpeed: pickEnum(AiSpeed.values, 'aiSpeed', d.aiSpeed),
      showHints: pick('showHints', d.showHints),
      confirmMove: pick('confirmMove', d.confirmMove),
      passDevice: pick('passDevice', d.passDevice),
      highContrast: pick('highContrast', d.highContrast),
      language: pick('language', d.language),
      playerColor: pick('playerColor', d.playerColor),
      playerToken: pick('playerToken', d.playerToken),
      tutorialSeen: pick('tutorialSeen', d.tutorialSeen),
    );
  }
}
