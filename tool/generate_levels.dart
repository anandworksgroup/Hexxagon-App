// Regenerates assets/levels/levels.json from the deterministic generator.
//
//   dart run tool/generate_levels.dart
import 'dart:convert';
import 'dart:io';

import 'package:hexadominate/engine/levels/level.dart';
import 'package:hexadominate/engine/levels/level_generator.dart';

void main() {
  final pack = LevelPack(
    levels: LevelGenerator.campaign(),
    challenges: LevelGenerator.challenges(),
  );
  final file = File('assets/levels/levels.json');
  file.writeAsStringSync(jsonEncode(pack.toJson()));
  final byTier = <LevelTier, List<int>>{};
  for (final l in pack.levels) {
    byTier.putIfAbsent(l.tier!, () => []).add(l.cells.length);
  }
  for (final e in byTier.entries) {
    final sizes = e.value..sort();
    stdout.writeln('${e.key.label.padRight(13)} ${sizes.length} levels, '
        'cells ${sizes.first}-${sizes.last}');
  }
  stdout.writeln('${pack.challenges.length} challenges');
  stdout.writeln('Wrote ${file.path} (${file.lengthSync() ~/ 1024} KB)');
}
