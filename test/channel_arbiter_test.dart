import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/features/walkie/data/channel_arbiter.dart';

void main() {
  late int now;
  late ChannelArbiter arb;

  setUp(() {
    now = 1000;
    arb = ChannelArbiter(
      now: () => now,
      collisionWindowMs: 250,
      guardMs: 250,
      idleTimeoutMs: 1200,
      txIdleMs: 400,
    );
  });

  group('ChannelArbiter — 로컬 송신', () {
    test('idle → requestLocal granted → txLocal, release → idle', () {
      expect(arb.requestLocal(), isTrue);
      expect(arb.state, ArbiterState.txLocal);
      arb.releaseLocal();
      expect(arb.state, ArbiterState.idle);
    });

    test('이미 txLocal이면 재요청은 허용', () {
      expect(arb.requestLocal(), isTrue);
      expect(arb.requestLocal(), isTrue);
      expect(arb.state, ArbiterState.txLocal);
    });

    test('txLocal에서 오디오 없이 txIdleMs(400) 경과 → 자동 해제', () {
      arb.requestLocal();
      now += 401;
      arb.tick();
      expect(arb.state, ArbiterState.idle);
      expect(arb.busyRemote, isFalse);
    });

    test('keepaliveLocal은 자동 해제를 늦춘다', () {
      arb.requestLocal();
      now += 300;
      arb.keepaliveLocal();
      now += 300; // 400ms 유지 구간 내
      arb.tick();
      expect(arb.state, ArbiterState.txLocal);
      now += 300;
      arb.tick();
      expect(arb.state, ArbiterState.idle);
    });
  });

  group('ChannelArbiter — 원격 점유/거부', () {
    test('타인 TX_START → rxRemote, requestLocal 거부', () {
      arb.peerStart('peer-a');
      expect(arb.state, ArbiterState.rxRemote);
      expect(arb.busyRemote, isTrue);
      expect(arb.requestLocal(), isFalse);
    });

    test('peerAudio는 rx 유휴를 연장', () {
      arb.peerStart('peer-a');
      now += 1000;
      arb.peerAudio('peer-a');
      now += 1000;
      expect(arb.busyRemote, isTrue); // 1200ms 미만 유지
      now += 300;
      arb.tick();
      expect(arb.state, ArbiterState.idle);
    });

    test('rx idleTimeout(1200ms) 경과 → idle', () {
      arb.peerStart('peer-a');
      now += 1201;
      arb.tick();
      expect(arb.state, ArbiterState.idle);
    });

    test('TX_END 후 guardMs(250) 동안 버스 유지 → 이후 idle', () {
      arb.peerStart('peer-a');
      arb.peerEnd();
      expect(arb.state, ArbiterState.rxRemote); // guard 유지
      now += 250 - 1;
      arb.tick();
      expect(arb.state, ArbiterState.rxRemote);
      now += 2;
      arb.tick();
      expect(arb.state, ArbiterState.idle);
    });

    test('peerLeft는 버스 소유자만 해제', () {
      arb.peerStart('peer-a');
      arb.peerLeft('peer-b'); // 다른 상대 → 무시
      expect(arb.state, ArbiterState.rxRemote);
      arb.peerLeft('peer-a');
      expect(arb.state, ArbiterState.idle);
    });
  });

  group('ChannelArbiter — 충돌 / 양보', () {
    test('txLocal 후 250ms 내 타인 starts → 충돌', () {
      arb.requestLocal();
      now += 100;
      final yielded = arb.peerStart('peer-b');
      expect(yielded, isFalse);
      expect(arb.takeCollision(), isTrue);
      expect(arb.takeCollision(), isFalse); // 1회 소비
    });

    test('충돌 윈도(250ms) 통과 후 타인 starts → 양보', () {
      arb.requestLocal();
      now += 300;
      final yielded = arb.peerStart('peer-b');
      expect(yielded, isTrue); // 우리 송신 중단해야 함
      expect(arb.takeCollision(), isFalse);
      expect(arb.state, ArbiterState.rxRemote);
      expect(arb.busyOwnerId, 'peer-b');
      // 양보 후 우리 재송신은 거부
      expect(arb.requestLocal(), isFalse);
    });
  });

  group('ChannelArbiter — busyOwnerId', () {
    test('busyOwnerId는 마지막 발화자', () {
      arb.peerStart('peer-a');
      expect(arb.busyOwnerId, 'peer-a');
      arb.peerAudio('peer-b');
      expect(arb.busyOwnerId, 'peer-b');
    });
  });
}
