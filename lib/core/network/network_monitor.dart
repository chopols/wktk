/// 네트워크 상태 감지: 사설 IPv4 탐지로 Wi-Fi/LAN 가용 여부 판정.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subnet.dart';

// 분류기/종류는 순수 Dart(`subnet.dart`)에 있고 앱에서 재수출한다.
export 'subnet.dart' show NetKind, NetworkClassifier;

/// 감지된 네트워크 상태 스냅샷.
@immutable
class NetworkStatus {
  const NetworkStatus({
    required this.connected,
    this.kind = NetKind.unknown,
    this.localIPv4,
  });

  final bool connected;
  final NetKind kind;

  /// 첫 번째로 발견된 사설 IPv4 (유니캐스트 폴백용).
  final String? localIPv4;

  static const disconnected = NetworkStatus(
    connected: false,
    kind: NetKind.none,
  );
}

/// 3초 주기로 인터페이스를 샘플링한다. 디스포즈 시 타이머 정리.
class NetworkMonitor extends Notifier<NetworkStatus> {
  static const sampleInterval = Duration(seconds: 3);
  Timer? _timer;

  @override
  NetworkStatus build() {
    _timer = Timer.periodic(sampleInterval, (_) => unawaited(_refresh()));
    ref.onDispose(() => _timer?.cancel());
    unawaited(_refresh());
    return NetworkStatus.disconnected;
  }

  Future<void> _refresh() async {
    Iterable<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    } catch (_) {
      state = NetworkStatus.disconnected;
      return;
    }

    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final ip = addr.address;
        if (!NetworkClassifier.isPrivateIPv4(ip)) continue;
        state = NetworkStatus(
          connected: true,
          kind: NetworkClassifier.classify(iface.name, ip),
          localIPv4: ip,
        );
        return;
      }
    }
    state = NetworkStatus.disconnected;
  }
}

final networkStatusProvider = NotifierProvider<NetworkMonitor, NetworkStatus>(
  NetworkMonitor.new,
);
