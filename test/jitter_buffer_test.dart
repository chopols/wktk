import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/features/walkie/data/jitter_buffer.dart';

void main() {
  late int now;
  late JitterBuffer buf;

  Uint8List frame(int v) {
    final b = Uint8List(640);
    b[0] = v & 0xFF;
    return b;
  }

  setUp(() {
    now = 0;
    buf = JitterBuffer(
      targetMs: 60,
      maxDropMs: 120,
      maxReplayGapFrames: 6,
      nowMs: () => now,
    )..resetStats();
  });

  group('JitterBuffer — 워밍업', () {
    test('첫 프레임 도착 후 targetMs 경과 전에는 재생 안 함', () {
      buf.offer(1, frame(1));
      expect(buf.drain(), isEmpty);
      expect(buf.hasPending, isTrue);
      now = 59;
      expect(buf.drain(), isEmpty);
      now = 60;
      expect(buf.drain(), hasLength(1));
    });

    test('여러 프레임이 몰려도 순서 유지 + 도착 시각 기준 재생', () {
      for (var i = 1; i <= 5; i++) {
        buf.offer(i, frame(i));
      }
      now = 60;
      final out = buf.drain();
      expect(out, hasLength(5));
      expect(out.map((f) => f[0]).toList(), [1, 2, 3, 4, 5]);
    });
  });

  group('JitterBuffer — 순서 복원', () {
    test('out-of-order 도달은 순서대로 재생', () {
      buf.offer(1, frame(1));
      buf.offer(3, frame(3));
      buf.offer(2, frame(2));
      now = 60;
      final out = buf.drain();
      expect(out.map((f) => f[0]).toList(), [1, 2, 3]);
      expect(buf.outOfOrderDropped, 0);
    });

    test('워밍업 전 역순 도착은 버림', () {
      buf.offer(5, frame(5));
      buf.offer(2, frame(2)); // 5보다 작음 → out-of-order 폐기
      expect(buf.outOfOrderDropped, 1);
      now = 60;
      final out = buf.drain();
      expect(out.map((f) => f[0]).toList(), [5]);
    });
  });

  group('JitterBuffer — 중복/역전 폐기', () {
    test('같은 seq 중복 도착 → 1회만 재생', () {
      buf.offer(1, frame(1));
      buf.offer(1, frame(1));
      now = 60;
      expect(buf.drain(), hasLength(1));
      expect(buf.duplicateDropped, 1);
    });

    test('이미 재생된 seq 이하 도착 → 폐기', () {
      buf.offer(1, frame(1));
      now = 60;
      buf.drain();
      buf.offer(1, frame(1));
      buf.offer(0, frame(0));
      expect(buf.duplicateDropped, 2);
    });
  });

  group('JitterBuffer — PLC(손실 은폐)', () {
    test('seq 3 유실 시 마지막 프레임 홀드 1회', () {
      buf.offer(1, frame(1));
      buf.offer(2, frame(2));
      buf.offer(4, frame(4)); // 3 없이 4 도착
      now = 60;
      final out = buf.drain();
      // 1, 2, PLC(2 홀드), 4
      expect(out, hasLength(4));
      expect(out[2][0], 2); // PLC는 마지막 샘플
      expect(out[3][0], 4);
      expect(buf.plcInserted, 1);
    });

    test('연속 유실이 상한(6) 초과 시 홀 스킵', () {
      buf.offer(1, frame(1));
      buf.offer(100, frame(100)); // 2..99 유실
      now = 60;
      final out = buf.drain();
      // 1 → (갭 98 > 6) 홀 스킵 → 100
      expect(out.map((f) => f[0]).toList(), [1, 100]);
      expect(buf.plcInserted, 0);
      expect(buf.holeSkipped, 1);
    });
  });

  group('JitterBuffer — 버스트 종료', () {
    test('shouldStop: 재생 시작 후 maxDropMs 무소식이면 true', () {
      buf.offer(1, frame(1)); // t=0 수신
      now = 60;
      buf.drain();
      expect(buf.shouldStop(nowMs: 120), isFalse); // 정확히 120은 경계 밖(>)
      expect(buf.shouldStop(nowMs: 121), isTrue);
    });

    test('reset: 버스트 경계에서 큐와 지표 초기화', () {
      buf.offer(1, frame(1));
      buf.offer(2, frame(2));
      buf.reset();
      expect(buf.hasPending, isFalse);
      expect(buf.isActive, isFalse);
      buf.offer(100, frame(100));
      now = 60;
      expect(buf.drain(), hasLength(1));
    });
  });
}
