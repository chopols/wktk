import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/core/network/transport/dart_udp_transport.dart';
import 'package:wktk/core/network/transport/transport.dart';

/// 실제 운영 방식을 반영: 같은 채널의 노드들은 `reuseAddress`로 **동일 포트**를
/// 공유 바인딩하고, 포트는 `kBasePort + channel`(또는 테스트용 명시 포트) 고정.
void main() {
  group('DartUdpTransport 통합 (loopback)', () {
    test('서로 다른 바인딩 포트의 두 노드 간 유니캐스트 (senderId 매칭)', () async {
      final a = DartUdpTransport();
      final b = DartUdpTransport();
      await a.start(channel: 1, port: 46101);
      await b.start(channel: 1, port: 46102);
      addTearDown(() async {
        await a.stop();
        await b.stop();
      });

      final payload = Uint8List.fromList([9, 8, 7, 6, 5]);
      final got = Completer<ReceivedDatagram>();
      final sub = b.onPacket.listen(got.complete);

      // 실기기에서는 포트가 채널 고정포트이지만, 단일 호스트 루프백에서는
      // 동일 포트를 공유하면 배달 대상이 비결정적이므로 B의 포트를 명시.
      await a.sendTo(payload, '127.0.0.1', port: 46102);
      final rx = await got.future.timeout(const Duration(seconds: 3));
      await sub.cancel();

      expect(rx.data, payload);
    }, timeout: const Timeout(Duration(seconds: 8)));

    test('동일 채널 포트를 공유하는 두 노드 간 멀티캐스트 sendAll', () async {
      final a = DartUdpTransport();
      final b = DartUdpTransport();
      await a.start(channel: 5, port: 46110);
      await b.start(channel: 5, port: 46110);
      addTearDown(() async {
        await a.stop();
        await b.stop();
      });

      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final got = Completer<ReceivedDatagram>();
      final sub = b.onPacket.listen(got.complete);

      await a.sendAll(payload);
      final rx = await got.future.timeout(const Duration(seconds: 3));
      await sub.cancel();

      expect(rx.data, payload);
    }, timeout: const Timeout(Duration(seconds: 8)));
  });
}
