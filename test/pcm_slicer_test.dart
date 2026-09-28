import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/features/walkie/data/audio/audio_playback.dart'
    show pcm16Rms;
import 'package:wktk/features/walkie/data/audio/pcm_slicer.dart';

void main() {
  group('PcmSlicer (640B 프레임 절단)', () {
    test('정확히 640B 청크 1개 → 프레임 1개', () {
      final slicer = PcmSlicer(frameSize: 640);
      final frames = slicer.push(Uint8List(640));
      expect(frames.length, 1);
      expect(frames.first.length, 640);
      expect(slicer.pendingBytes, 0);
    });

    test('640B 미만은 보관', () {
      final slicer = PcmSlicer(frameSize: 640);
      final frames = slicer.push(Uint8List(100));
      expect(frames, isEmpty);
      expect(slicer.pendingBytes, 100);
    });

    test('여러 청크로 640B 구성', () {
      final slicer = PcmSlicer(frameSize: 640);
      expect(slicer.push(Uint8List(300)), isEmpty);
      expect(slicer.push(Uint8List(300)), isEmpty);
      final frames = slicer.push(Uint8List(40));
      expect(frames.length, 1);
      expect(slicer.pendingBytes, 0);
    });

    test('1900B → 2프레임 + 620B 꼬리', () {
      final slicer = PcmSlicer(frameSize: 640);
      final frames = slicer.push(Uint8List(1900));
      expect(frames.length, 2);
      expect(slicer.pendingBytes, 1900 - 640 * 2);
    });

    test('꼬리 이어붙이기 (경계 부정합)', () {
      final slicer = PcmSlicer(frameSize: 640);
      expect(slicer.push(Uint8List(640 + 100)), hasLength(1));
      expect(slicer.pendingBytes, 100);
      final frames = slicer.push(Uint8List(640 - 100));
      expect(frames, hasLength(1));
      expect(slicer.pendingBytes, 0);
    });

    test('flush는 꼬리를 버리고 비운다', () {
      final slicer = PcmSlicer(frameSize: 640);
      slicer.push(Uint8List(10));
      final tail = slicer.flush();
      expect(tail, isNull);
      expect(slicer.pendingBytes, 0);
    });

    test('flush(dropTail:false)는 꼬리를 반환한다', () {
      final slicer = PcmSlicer(frameSize: 640);
      final input = Uint8List.fromList(List.generate(10, (i) => i));
      slicer.push(input);
      final tail = slicer.flush(dropTail: false);
      expect(tail, isNotNull);
      expect(tail, input);
    });

    test('clear 후 초기화', () {
      final slicer = PcmSlicer(frameSize: 640);
      slicer.push(Uint8List(700));
      expect(slicer.pendingBytes, 60);
      slicer.clear();
      expect(slicer.pendingBytes, 0);
    });
  });

  group('pcm16Rms', () {
    test('정적(무음) → 0', () {
      expect(pcm16Rms(Uint8List(640)), 0.0);
    });

    test('최대 진폭 → 1 근사', () {
      final pcm = Uint8List(640);
      final bd = ByteData.sublistView(pcm);
      for (var i = 0; i < 320; i++) {
        bd.setInt16(i * 2, 32767, Endian.little);
      }
      expect(pcm16Rms(pcm), closeTo(1.0, 1e-3));
    });

    test('절반 진폭 → ~0.5', () {
      final pcm = Uint8List(640);
      final bd = ByteData.sublistView(pcm);
      for (var i = 0; i < 320; i++) {
        bd.setInt16(i * 2, 16384, Endian.little);
      }
      expect(pcm16Rms(pcm), closeTo(0.5, 0.01));
    });

    test('빈 데이터 → 0', () {
      expect(pcm16Rms(Uint8List(0)), 0.0);
    });
  });
}
