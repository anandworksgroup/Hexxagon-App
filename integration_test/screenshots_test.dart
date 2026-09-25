// Walks the app on a real device and captures the Play Store screenshots:
//
//   flutter drive --driver test_driver/integration_test.dart \
//     --target integration_test/screenshots_test.dart --profile
//
// Images land in store/screenshots/. It also doubles as a smoke test: every
// screen here has to build and respond to taps on a real device.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hexadominate/main.dart' as app;
import 'package:hexadominate/ui/widgets/hex_board.dart';
import 'package:integration_test/integration_test.dart';

Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump(Duration(milliseconds: ms));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> tapText(WidgetTester tester, String text, {int settleMs = 700}) async {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: 'looking for "$text"');
  await tester.tap(finder.first);
  await settle(tester, settleMs);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture store screenshots', (tester) async {
    // Android needs the Flutter surface converted before it can be captured.
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    final semantics = tester.ensureSemantics();
    app.main();
    await settle(tester, 1600);

    // First run opens the tutorial; grab a page of it, then skip.
    if (find.text('SKIP').evaluate().isNotEmpty) {
      await binding.takeScreenshot('01-tutorial');
      await tapText(tester, 'SKIP');
    }

    await binding.takeScreenshot('02-home');

    // Level map.
    await tapText(tester, 'LEVELS');
    await binding.takeScreenshot('03-levels');

    // Level 1 intro sheet, then play it.
    await tapText(tester, '1');
    await binding.takeScreenshot('04-level-intro');
    await tapText(tester, 'PLAY', settleMs: 1200);

    // Select one of our tokens so the move hints are showing. Cells are
    // painted, not widgets, so probe the board until the coaching line
    // confirms a token is selected.
    final board = find.byType(HexBoard);
    final rect = tester.getRect(board);
    const probes = <Offset>[
      Offset(0.85, 0.5),
      Offset(0.15, 0.5),
      Offset(0.5, 0.15),
      Offset(0.5, 0.85),
      Offset(0.8, 0.25),
      Offset(0.2, 0.75),
    ];
    for (final p in probes) {
      await tester.tapAt(rect.topLeft + Offset(rect.width * p.dx, rect.height * p.dy));
      await settle(tester, 500);
      if (find.textContaining('Tap a highlighted hex').evaluate().isNotEmpty) break;
    }
    await binding.takeScreenshot('05-game');

    // Back out of the game: pause, exit, quit.
    await tester.tap(find.byTooltip('Pause'));
    await settle(tester);
    await binding.takeScreenshot('06-pause');
    await tapText(tester, 'EXIT GAME');
    await tapText(tester, 'QUIT');

    // Challenges (via Play).
    await tapText(tester, 'PLAY');
    await binding.takeScreenshot('07-play-menu');
    await tapText(tester, 'CHALLENGE');
    await binding.takeScreenshot('08-challenge');
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    // Tokens, statistics, settings.
    await tapText(tester, 'Tokens');
    await binding.takeScreenshot('09-tokens');
    await tester.pageBack();
    await settle(tester);
    await tapText(tester, 'Statistics');
    await binding.takeScreenshot('10-statistics');
    await tester.pageBack();
    await settle(tester);
    await tapText(tester, 'Settings');
    await binding.takeScreenshot('11-settings');
    await tester.pageBack();
    await settle(tester);

    semantics.dispose();
  });
}
