// CLI 생성 도구이므로 print 사용을 허용.
// ignore_for_file: avoid_print

/// 무전기 효과음 WAV 오프라인 생성.
///
/// 44000 Hz mono 16-bit PCM을 `assets/sounds/`에 기록한다.
/// roger_beep(PTT 시작/종료 비프), squelch_tone(RX 시작 블립),
/// denied_tone(거부 버즈).
/// 사용: `dart run tool/gen_sounds.dart`
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

void main() {
  final outDir = Directory('assets/sounds');
  outDir.createSync(recursive: true);

  _write(
    '${outDir.path}/roger_beep.wav',
    _tone(freqs: const [1320, 1760], segmentsMs: const [50, 50], amp: 0.45),
  );
  _write(
    '${outDir.path}/squelch_tone.wav',
    _tone(freqs: const [2200], segmentsMs: const [28], amp: 0.32),
  );
  _write(
    '${outDir.path}/denied_tone.wav',
    _tone(freqs: const [330, 220], segmentsMs: const [110, 110], amp: 0.5),
  );
  print('생성 완료 → assets/sounds/ (roger_beep, squelch_tone, denied_tone)');
}

/// 순차 주파수/지속시간(ms) 세그먼트로 사인 톤 생성(로컬 차단 없이 fade).
List<double> _tone({
  required List<int> freqs,
  required List<int> segmentsMs,
  required double amp,
}) {
  var samples = <double>[];
  var phase = 0.0;
  for (var i = 0; i < freqs.length; i++) {
    final n = segmentsMs[i] * sampleRate ~/ 1000;
    final fade = math.min(4, n ~/ 8);
final seg = List<double>.generate(n, (j) {
      final env = j < fade
          ? (j + 0.5) / fade
          : j >= n - fade
              ? (n - j - 0.5) / fade
              : 1.0;
      phase += 2 * math.pi * freqs[i] / sampleRate;
      return amp * env * math.sin(phase);
    });
    samples.addAll(seg);
  }
  return samples;
}

void _write(String path, List<double> samples) {
  final pcm = Uint8List(samples.length * 2);
  final bd = ByteData.sublistView(pcm);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 32767).round().clamp(-32768, 32767);
    bd.setInt16(i * 2, v, Endian.little);
  }
  final file = File(path);
  file.writeAsBytesSync(_wavHeader(samples.length) + pcm);
}

Uint8List _wavHeader(int sampleCount) {
  final dataBytes = sampleCount * 2;
  final header = ByteData(44);
  _fourcc(header, 0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  _fourcc(header, 8, 'WAVE');
  _fourcc(header, 12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // fmt chunk size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits
  _fourcc(header, 36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

void _fourcc(ByteData h, int offset, String s) {
  for (var i = 0; i < 4; i++) {
    h.setUint8(offset + i, s.codeUnitAt(i));
  }
}
