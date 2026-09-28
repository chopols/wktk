/// 무전기 전송 추상화 (Flutter 비의존 순수 Dart).
library;

import 'dart:io';
import 'dart:typed_data';

/// 수신 데이터그램.
typedef ReceivedDatagram = ({Uint8List data, InternetAddress from, int port});

/// 전송 계층 인터페이스. RX는 채널 고정포트, TX는 이 소켓으로 멀티캐스트/브로드캐스트/유니캐스트를 보낸다.
abstract interface class RadioTransport {
  bool get started;
  int get channel;

  /// [port] 미지정 시 `kBasePort + channel`.
  Future<void> start({required int channel, int? port});

  Future<void> stop();

  /// 3경로(멀티캐스트 + 브로드캐스트 후보) 동시 발송.
  Future<void> sendAll(Uint8List datagram);

  /// 특정 수신처로 유니캐스트. [port] 미지정 시 채널 고정 포트(=자신의 바인딩 포트) 사용.
  Future<void> sendTo(Uint8List datagram, String address, {int? port});

  /// 로컬 사설 IPv4 (브로드캐스트 후보 계산용).
  void setLocalIpv4(String? ip);

  Stream<ReceivedDatagram> get onPacket;
}
