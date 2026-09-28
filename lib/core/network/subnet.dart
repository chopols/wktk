/// IP 주소 유틸 + 네트워크 분류기 (Flutter 비의존 순수 Dart).
///
/// `radio_sim`의 `dart run` 호환을 위해 flutter 패키지를 참조하지 않는다.
library;

import '../constants/app_constants.dart';

/// IPv4 문자열 → 32비트 정수.
int ipv4ToInt(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) throw FormatException('IPv4 아님: $ip');
  var value = 0;
  for (final p in parts) {
    final o = int.parse(p);
    if (o < 0 || o > 255) throw FormatException('IPv4 옥텟 오류: $p');
    value = (value << 8) | o;
  }
  return value;
}

String intToIpv4(int value) {
  return '${(value >> 24) & 0xFF}.${(value >> 16) & 0xFF}.'
      '${(value >> 8) & 0xFF}.${value & 0xFF}';
}

/// Dart가 netmask를 노출하지 않으므로 사설 IPv4는 **/24**로 가정해
/// 서브넷 브로드캐스트 주소를 계산한다 (홈 LAN 분포 기준).
String subnetBroadcast24(String ipv4) {
  return intToIpv4(ipv4ToInt(ipv4) | 0x000000FF);
}

/// 브로드캐스트 전송에 사용할 후보 주소들 (전역 + /24 가정).
List<String> broadcastCandidates(String? localIPv4) {
  final candidates = <String>{AppConstants.kBroadcastAddress};
  if (localIPv4 != null && localIPv4.contains('.')) {
    try {
      candidates.add(subnetBroadcast24(localIPv4));
    } on FormatException {
      // 무시
    }
  }
  return candidates.toList();
}

/// 추정 네트워크 종류 (이동: `core/network/network_monitor.dart`에서 사용).
enum NetKind { unknown, wifi, cellular, none }

/// 순수 분류 로직 (단위 테스트 대상).
class NetworkClassifier {
  NetworkClassifier._();

  /// 사설 IPv4 대역 여부: 10/8, 172.16/12, 192.168/16.
  static bool isPrivateIPv4(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null)) return false;
    final a = octets[0]!, b = octets[1]!;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  /// 인터페이스 이름 기반 추정 (실기기 관례).
  static NetKind classify(String interfaceName, String address) {
    final n = interfaceName.toLowerCase();
    if (n.contains('rmnet') ||
        n.contains('ccmni') ||
        n.contains('pdp') ||
        n.contains('wwan') ||
        n.contains('cell')) {
      return NetKind.cellular;
    }
    if (isPrivateIPv4(address)) {
      return n.contains('wlan') ||
              n.contains('wifi') ||
              n.contains('eth') ||
              n.contains('ether') ||
              n.startsWith('en')
          ? NetKind.wifi
          : NetKind.unknown;
    }
    return NetKind.none;
  }
}
