# HexaDominate — Conquer every hex.

An offline hexagonal strategy game for Android, iPhone and iPad (Flutter).
No account, no server, no ads, no analytics, no internet permission in release builds.

## Rules
- **Multiply**: move a token to a neighbouring empty hex. The original stays (+1 token).
- **Jump**: move a token to an empty hex exactly two steps away. The original hex empties.
- **Capture**: every enemy token next to the hex you land on becomes yours.
- The game ends when the board is full, no one can move, only one player is left,
  every human is wiped out, or after 80 moves without a multiply (so jumping can't loop forever).
  A player with no legal move is skipped. Most hexes wins, and a tie for the top is a draw.

## Layout
| Path | What |
|---|---|
| `lib/engine/` | Pure Dart with no Flutter imports: axial hex math, `BoardLayout`, `GameState`, `GameEngine` (the only place rules live) |
| `lib/engine/ai/` | Easy (greedy), Normal (1-ply eval), Hard (alpha-beta), Expert (iterative deepening). Weights live in `AiWeights` |
| `lib/engine/levels/` | Level model and the deterministic generator (campaign, challenges, daily, quick boards) |
| `lib/data/` | Settings (SharedPreferences), profile/progress/stats, crash-safe JSON store (temp file + rename + `.bak`) |
| `lib/state/` | Riverpod: `GameController` (turn flow, AI in a background isolate, autosave after every move, undo, results) |
| `lib/ui/` | Screens and the `CustomPainter` board (`widgets/hex_board.dart`) |
| `assets/levels/levels.json` | 300 levels + 30 challenges, generated |
| `assets/sounds/` | Synthesised SFX and music loop, generated |

## Tools
```bash
dart run tool/generate_levels.dart     # regenerate assets/levels/levels.json
dart run tool/generate_sounds.dart     # regenerate assets/sounds/*.wav
dart run tool/ai_arena.dart 8          # self-play: each AI level vs the one below
flutter test tool/icons_test.dart      # re-render Android + iOS app icons
flutter test                           # engine, levels, controller, persistence tests
```
The level test checks that the bundled JSON still matches the generator. After you change
the generator, regenerate the JSON.

## Building on this machine
Gradle needs `TMP='C:\gradle-tmp' TEMP='C:\gradle-tmp' flutter build apk`.
iOS (deployment target 15.0, Podfile included) must be built on a Mac.
Release signing is not set up yet, so `release` still uses the debug keys.
