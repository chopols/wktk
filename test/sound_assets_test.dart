import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// `tool/gen_sounds.dart`로 생성된 효과음 자산의 유효성을 검증.
void main() {
  const files = ['roger_beep.wav', 'squelch_tone.wav', 'denied_tone.wav'];

  for (final name in files) {
    test('$name — RIFF/WAVE mono 16bit 헤더 + 데이터 크기', () {
      final f = File('assets/sounds/$name');
      expect(
        f.existsSync(),
        isTrue,
        reason:
            '$name 이(가) 없습니다. '
            '먼저 `dart run tool/gen_sounds.dart`를 실행하세요.',
      );
      final bytes = f.readAsBytesSync();
      expect(bytes.length, greaterThan(44));
      final bd = ByteData.sublistView(bytes);
      expect(_ascii(bytes, 0, 4), 'RIFF');
      expect(_ascii(bytes, 8, 4), 'WAVE');
      expect(_ascii(bytes, 12, 4), 'fmt ');
      expect(bd.getUint16(20, Endian.little), 1); // PCM
      expect(bd.getUint16(22, Endian.little), 1); // mono
      expect(bd.getUint32(24, Endian.little), 44100); // sample rate
      expect(bd.getUint16(34, Endian.little), 16); // 16bit
      expect(_ascii(bytes, 36, 4), 'data');
      final dataBytes = bd.getUint32(40, Endian.little);
      expect(bytes.length, 44 + dataBytes);
      expect(dataBytes, greaterThan(0));
      expect(dataBytes.isEven, isTrue);
    });
  }
}

String _ascii(Uint8List b, int start, int len) =>
    String.fromCharCodes(b.sublist(start, start + len));
