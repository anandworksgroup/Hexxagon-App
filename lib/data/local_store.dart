import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Crash-safe JSON files in the app's private directory.
///
/// Every write goes to `name.tmp` first and is then renamed over the real
/// file, keeping the previous good copy as `name.bak`. A torn write (app
/// killed mid-save) therefore never leaves a half-written file in place, and
/// a corrupt file falls back to the last good one.
class LocalStore {
  LocalStore(this.directory);

  final Directory directory;

  /// Writes are chained so two quick saves can't race on the same temp file.
  Future<void> _queue = Future.value();

  File _file(String name) => File('${directory.path}${Platform.pathSeparator}$name.json');
  File _bak(String name) => File('${directory.path}${Platform.pathSeparator}$name.json.bak');
  File _tmp(String name) => File('${directory.path}${Platform.pathSeparator}$name.json.tmp');

  /// Reads [name], falling back to the backup copy. Returns null when neither
  /// exists or both fail [validate].
  Map<String, dynamic>? read(String name, {bool Function(Map<String, dynamic>)? validate}) {
    for (final f in [_file(name), _bak(name)]) {
      try {
        if (!f.existsSync()) continue;
        final decoded = jsonDecode(f.readAsStringSync());
        if (decoded is! Map<String, dynamic>) continue;
        if (validate != null && !validate(decoded)) continue;
        return decoded;
      } catch (_) {
        // Corrupt: try the next copy.
      }
    }
    return null;
  }

  Future<void> write(String name, Map<String, dynamic> data) {
    final text = jsonEncode(data);
    return _queue = _queue.then((_) => _writeNow(name, text)).catchError((_) {});
  }

  Future<void> _writeNow(String name, String text) async {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final tmp = _tmp(name);
    await tmp.writeAsString(text, flush: true);
    final main = _file(name);
    if (main.existsSync()) {
      try {
        await main.copy(_bak(name).path);
      } catch (_) {}
    }
    await tmp.rename(main.path);
  }

  Future<void> delete(String name) {
    return _queue = _queue.then((_) async {
      for (final f in [_file(name), _bak(name), _tmp(name)]) {
        try {
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    });
  }

  /// Waits for pending writes (used before export and in tests).
  Future<void> flush() => _queue;
}
