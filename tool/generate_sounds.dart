// Synthesises the game's sound effects and ambient music loop as WAV files
// into assets/sounds/. Everything is original and generated, so there are no
// third-party audio licences to track.
//
//   dart run tool/generate_sounds.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;

void main() {
  Directory('assets/sounds').createSync(recursive: true);
  _write('tick', _tone([(1760, 0.035)], decay: 90, gain: 0.35));
  _write('move', _sweep(520, 700, 0.09, gain: 0.4));
  _write('capture', _tone([(740, 0.06), (990, 0.08)], decay: 30, gain: 0.45));
  _write('success', _tone([(523, 0.11), (659, 0.11), (784, 0.11), (1046, 0.3)], decay: 9, gain: 0.45));
  _write('failure', _tone([(440, 0.16), (370, 0.16), (294, 0.35)], decay: 7, gain: 0.4));
  _write(
    'achievement',
    _tone([(784, 0.08), (988, 0.08), (1175, 0.08), (1568, 0.35)], decay: 8, gain: 0.42),
  );
  _write('music', _music(), sampleRate: 16000);
}

/// Consecutive notes (frequency, seconds) with a soft attack and
/// exponential decay per note.
Float64List _tone(List<(double, double)> notes, {required double decay, double gain = 0.5}) {
  final total = notes.fold<double>(0, (a, n) => a + n.$2);
  final out = Float64List((total * rate).ceil() + rate ~/ 20);
  var start = 0;
  for (final (f, dur) in notes) {
    final len = (dur * rate).round();
    final tail = len + rate ~/ 10;
    for (var i = 0; i < tail && start + i < out.length; i++) {
      final t = i / rate;
      final env = math.min(1.0, i / (rate * 0.004)) * math.exp(-t * decay);
      final s = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t);
      out[start + i] += s * env * gain * 0.8;
    }
    start += len;
  }
  return out;
}

Float64List _sweep(double f0, double f1, double dur, {double gain = 0.5}) {
  final len = (dur * rate).round() + rate ~/ 20;
  final out = Float64List(len);
  var phase = 0.0;
  for (var i = 0; i < len; i++) {
    final t = i / rate;
    final f = f0 + (f1 - f0) * math.min(1.0, t / dur);
    phase += 2 * math.pi * f / rate;
    final env = math.min(1.0, i / (rate * 0.004)) * math.exp(-t * 28);
    out[i] = math.sin(phase) * env * gain;
  }
  return out;
}

/// A calm 24-second pad loop (Am – F – C – G). Each chord fades in and out
/// completely so the loop point is seamless.
Float64List _music() {
  const sr = 16000;
  const chordLen = 6.0;
  const chords = [
    [220.0, 261.63, 329.63],
    [174.61, 220.0, 261.63],
    [196.0, 261.63, 329.63],
    [196.0, 246.94, 293.66],
  ];
  final out = Float64List((chords.length * chordLen * sr).round());
  for (var c = 0; c < chords.length; c++) {
    final start = (c * chordLen * sr).round();
    // Overlap into the next chord slot for a smooth crossfade.
    final len = ((chordLen + 1.5) * sr).round();
    for (var i = 0; i < len; i++) {
      final t = i / sr;
      final env = math.sin(math.pi * math.min(1.0, t / (chordLen + 1.5)));
      var s = 0.0;
      for (final f in chords[c]) {
        s += math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t + 0.4);
        // Gentle shimmer.
        s += 0.08 * math.sin(2 * math.pi * f * 3.01 * t) * (0.5 + 0.5 * math.sin(t * 1.3));
      }
      final idx = (start + i) % out.length;
      out[idx] += s * env * 0.09;
    }
  }
  return out;
}

void _write(String name, Float64List samples, {int sampleRate = rate}) {
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  final norm = peak > 0.95 ? 0.95 / peak : 1.0;
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * norm * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  File('assets/sounds/$name.wav').writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('assets/sounds/$name.wav  ${(samples.length / sampleRate).toStringAsFixed(2)}s');
}
