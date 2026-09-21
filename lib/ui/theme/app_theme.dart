import 'package:flutter/material.dart';

import '../../data/settings.dart';

/// Colours used by the game surfaces. Read with `context.palette`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.board,
    required this.boardEdge,
    required this.text,
    required this.textSecondary,
    required this.players,
    required this.symbol,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color board;
  final Color boardEdge;
  final Color text;
  final Color textSecondary;

  /// Player colours in [colorNames] order.
  final List<Color> players;

  /// Colour of the symbol drawn inside a token.
  final Color symbol;
  final bool isDark;

  Color player(int index) => players[index % players.length];

  static const _brightPlayers = [
    Color(0xFFF7C948), // yellow
    Color(0xFFA880F5), // purple
    Color(0xFFFF8A3D), // orange
    Color(0xFF4DA3FF), // blue
    Color(0xFF4CD483), // green
    Color(0xFFFF6FB1), // pink
  ];

  // Slightly deeper tones so tokens keep their contrast on light cells.
  static const _deepPlayers = [
    Color(0xFFE0A800),
    Color(0xFF8A5CE6),
    Color(0xFFF26B1D),
    Color(0xFF2F86E8),
    Color(0xFF1FB463),
    Color(0xFFE8458F),
  ];

  static Palette of(AppThemeKind kind, {bool highContrast = false}) {
    final p = switch (kind) {
      AppThemeKind.dark => const Palette(
        background: Color(0xFF151515),
        surface: Color(0xFF222222),
        surfaceHigh: Color(0xFF2C2C2C),
        board: Color(0xFF303030),
        boardEdge: Color(0xFF3B3B3B),
        text: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFAAAAAA),
        players: _brightPlayers,
        symbol: Color(0xFF151515),
        isDark: true,
      ),
      AppThemeKind.light => const Palette(
        background: Color(0xFFF3F3F1),
        surface: Color(0xFFFFFFFF),
        surfaceHigh: Color(0xFFE9E9E6),
        board: Color(0xFFDADAD6),
        boardEdge: Color(0xFFC2C2BD),
        text: Color(0xFF151515),
        textSecondary: Color(0xFF5B5B5B),
        players: _deepPlayers,
        symbol: Color(0xFFFFFFFF),
        isDark: false,
      ),
      AppThemeKind.midnight => const Palette(
        background: Color(0xFF0B1020),
        surface: Color(0xFF151C33),
        surfaceHigh: Color(0xFF1C2542),
        board: Color(0xFF222B45),
        boardEdge: Color(0xFF2F3A5C),
        text: Color(0xFFEEF2FF),
        textSecondary: Color(0xFF9AA5C4),
        players: _brightPlayers,
        symbol: Color(0xFF0B1020),
        isDark: true,
      ),
      AppThemeKind.oled => const Palette(
        background: Color(0xFF000000),
        surface: Color(0xFF111111),
        surfaceHigh: Color(0xFF1A1A1A),
        board: Color(0xFF1E1E1E),
        boardEdge: Color(0xFF2C2C2C),
        text: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFA0A0A0),
        players: _brightPlayers,
        symbol: Color(0xFF000000),
        isDark: true,
      ),
    };
    if (!highContrast) return p;
    return Palette(
      background: p.background,
      surface: p.surface,
      surfaceHigh: p.surfaceHigh,
      board: p.board,
      boardEdge: p.isDark ? const Color(0xFF7A7A7A) : const Color(0xFF6E6E6E),
      text: p.text,
      textSecondary: p.isDark ? const Color(0xFFDDDDDD) : const Color(0xFF2E2E2E),
      players: p.players,
      symbol: p.symbol,
      isDark: p.isDark,
    );
  }

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 || other == null ? this : other;
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Settings settings) {
  final p = Palette.of(settings.theme, highContrast: settings.highContrast);
  final accent = p.player(settings.playerColor);
  final scheme = ColorScheme(
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    primary: accent,
    onPrimary: p.symbol,
    secondary: accent,
    onSecondary: p.symbol,
    error: const Color(0xFFFF5A5A),
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.symbol : p.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : p.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceHigh,
      contentTextStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
