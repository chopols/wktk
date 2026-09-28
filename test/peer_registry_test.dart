import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/core/constants/app_constants.dart';
import 'package:wktk/features/walkie/data/peer_registry.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  group('PeerRegistry', () {
    test('PRESENCE 수신 시 접속자 추가/표시 이름 갱신', () {
      final registry = PeerRegistry();
      registry.upsertPresence(
        id: 'a',
        nickname: '오리',
        address: '192.168.0.10',
        port: 45001,
        txActive: false,
        now: t0,
      );
      expect(registry.count, 1);
      expect(registry.byId('a')!.nickname, '오리');
      expect(registry.peers.first.address, '192.168.0.10');

      // 닉네임 변경 반영
      registry.upsertPresence(
        id: 'a',
        nickname: '비버',
        address: '192.168.0.10',
        port: 45001,
        txActive: true,
        now: t0.add(Duration(seconds: 2)),
      );
      expect(registry.count, 1);
      final peer = registry.byId('a')!;
      expect(peer.nickname, '비버');
      expect(peer.txActive, isTrue);
      expect(peer.lastSeen, t0.add(Duration(seconds: 2)));
    });

    test('여러 접속자와 독립 관리', () {
      final registry = PeerRegistry();
      for (var i = 0; i < 5; i++) {
        registry.upsertPresence(
          id: 'p$i',
          nickname: 'n$i',
          address: '192.168.0.1$i',
          port: 45001,
          txActive: false,
          now: t0,
        );
      }
      expect(registry.count, 5);
    });

    test('id 갱신/제거', () {
      final registry = PeerRegistry();
      registry.upsertPresence(
        id: 'a',
        nickname: 'a',
        address: 'x',
        port: 1,
        txActive: false,
        now: t0,
      );
      registry.upsertPresence(
        id: 'b',
        nickname: 'b',
        address: 'y',
        port: 1,
        txActive: false,
        now: t0,
      );
      registry.remove('a');
      expect(registry.count, 1);
      expect(registry.byId('a'), isNull);
      registry.clear();
      expect(registry.isEmpty, isTrue);
    });

    test('kPeerTimeout 초과 시 만료 purge', () {
      final registry = PeerRegistry();
      registry.upsertPresence(
        id: 'a',
        nickname: 'a',
        address: 'x',
        port: 1,
        txActive: false,
        now: t0,
      );
      registry.upsertPresence(
        id: 'b',
        nickname: 'b',
        address: 'y',
        port: 1,
        txActive: false,
        now: t0,
      );

      registry.purge(t0.add(AppConstants.kPeerTimeout + Duration(seconds: 1)));
      expect(registry.count, 0);

      // 여전히 살아있는 접속자 유지
      registry.upsertPresence(
        id: 'c',
        nickname: 'c',
        address: 'z',
        port: 1,
        txActive: false,
        now: t0,
      );
      registry.purge(t0.add(Duration(seconds: 4)));
      expect(registry.byId('c'), isNotNull);
    });
  });
}
