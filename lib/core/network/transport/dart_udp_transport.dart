/// Dart UDP 전송 구현 (Flutter 비의존 순수 Dart).
///
/// - RX: `anyIPv4:<kBasePort+channel>` 고정포트, `reuseAddress` 바인딩 후 멀티캐스트 join
/// - TX: 같은 소켓에서 멀티캐스트 → 브로드캐스트(전역 + /24 가정) 순 발송
/// - 제약: Dart가 멀티캐스트 루프백 off API를 노출하지 않아 자기 패킷은
///   `senderId` 비교로 폐기한다(상위 계층). 브로드캐스트는 SO_BROADCAST 미노출로
///   일부 기기에서 전송 실패할 수 있어 SocketException은 무시한다.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../constants/app_constants.dart';
import '../subnet.dart';
import 'transport.dart';

class DartUdpTransport implements RadioTransport {
  DartUdpTransport({
    Future<bool> Function()? multicastLockAcquire,
    Future<void> Function()? multicastLockRelease,
  }) : _lockAcquire = multicastLockAcquire,
       _lockRelease = multicastLockRelease;

  final Future<bool> Function()? _lockAcquire;
  final Future<void> Function()? _lockRelease;

  RawDatagramSocket? _socket;
  StreamController<ReceivedDatagram>? _controller;
  String? _group;
  String? _localIPv4;
  int _channel = AppConstants.kDefaultChannel;
  bool _joined = false;

  @override
  bool get started => _socket != null;

  @override
  int get channel => _channel;

  @override
  void setLocalIpv4(String? ip) => _localIPv4 = ip;

  @override
  Future<void> start({required int channel, int? port}) async {
    await stop();
    _channel = channel;
    final p = port ?? AppConstants.kBasePort + channel;

    // 멀티캐스트 join 이전에 MulticastLock 획득 (Android).
    await (_lockAcquire?.call() ?? Future.value(false));

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      p,
      reuseAddress: true,
    );
    _socket = socket;

    _group = '${AppConstants.kMulticastPrefix}.$channel';
    try {
      socket.joinMulticast(InternetAddress(_group!));
      _joined = true;
    } catch (e) {
      _joined = false;
    }

    _controller = StreamController<ReceivedDatagram>.broadcast();
    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final dm = socket.receive();
        if (dm == null) return;
        _controller!.add((data: dm.data, from: dm.address, port: dm.port));
      },
      // 소켓 비동기 오류(브로드캐스트 전송 거부/WSAEACCES 등)는
      // 송신 경로에서 정상적으로 무시하고 받아들인다.
      onError: (Object _) {},
    );
  }

  @override
  Future<void> stop() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      if (_joined && _group != null) {
        try {
          socket.leaveMulticast(InternetAddress(_group!));
        } catch (_) {}
        _joined = false;
      }
      socket.close();
    }
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    await (_lockRelease?.call() ?? Future.value());
  }

  @override
  Future<void> sendAll(Uint8List datagram) async {
    final socket = _socket;
    final group = _group;
    final port = _port;
    if (socket == null || group == null || port == null) return;

    if (_joined) {
      try {
        socket.send(datagram, InternetAddress(group), port);
      } catch (_) {}
    }
    for (final addr in broadcastCandidates(_localIPv4)) {
      try {
        socket.send(datagram, InternetAddress(addr), port);
      } catch (_) {}
    }
  }

  @override
  Future<void> sendTo(Uint8List datagram, String address, {int? port}) async {
    final socket = _socket;
    final self = _port;
    if (socket == null || self == null) return;
    try {
      socket.send(datagram, InternetAddress(address), port ?? self);
    } catch (_) {}
  }

  int? get _port {
    final s = _socket;
    if (s == null) return null;
    return s.port;
  }

  @override
  Stream<ReceivedDatagram> get onPacket =>
      _controller?.stream ?? const Stream.empty();
}
