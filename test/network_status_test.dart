import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/core/network/network_monitor.dart';

void main() {
  group('NetworkClassifier.isPrivateIPv4', () {
    test('사설 대역 인식', () {
      expect(NetworkClassifier.isPrivateIPv4('10.0.0.5'), isTrue);
      expect(NetworkClassifier.isPrivateIPv4('10.255.255.255'), isTrue);
      expect(NetworkClassifier.isPrivateIPv4('172.16.0.1'), isTrue);
      expect(NetworkClassifier.isPrivateIPv4('172.31.255.255'), isTrue);
      expect(NetworkClassifier.isPrivateIPv4('192.168.1.1'), isTrue);
    });

    test('공인/링크로컬/잘못된 IP 배제', () {
      expect(NetworkClassifier.isPrivateIPv4('172.32.0.1'), isFalse);
      expect(NetworkClassifier.isPrivateIPv4('172.15.0.1'), isFalse);
      expect(NetworkClassifier.isPrivateIPv4('192.169.0.1'), isFalse);
      expect(NetworkClassifier.isPrivateIPv4('8.8.8.8'), isFalse);
      expect(NetworkClassifier.isPrivateIPv4('169.254.1.1'), isFalse);
      expect(NetworkClassifier.isPrivateIPv4('127.0.0.1'), isFalse);
      expect(NetworkClassifier.isPrivateIPv4('not-an-ip'), isFalse);
    });
  });

  group('NetworkClassifier.classify', () {
    test('Wi-Fi/이더넷 인터페이스', () {
      expect(NetworkClassifier.classify('wlan0', '10.1.1.1'), NetKind.wifi);
      expect(NetworkClassifier.classify('eth0', '192.168.0.4'), NetKind.wifi);
      expect(NetworkClassifier.classify('en0', '192.168.0.4'), NetKind.wifi);
      expect(NetworkClassifier.classify('Ethernet', '10.0.0.2'), NetKind.wifi);
    });

    test('셀룰러 인터페이스', () {
      expect(
        NetworkClassifier.classify('rmnet0', '10.1.1.1'),
        NetKind.cellular,
      );
      expect(
        NetworkClassifier.classify('ccmni0', '192.168.0.4'),
        NetKind.cellular,
      );
      expect(
        NetworkClassifier.classify('wwan1', '10.20.30.40'),
        NetKind.cellular,
      );
      expect(
        NetworkClassifier.classify('pdp_ip0', '100.64.0.1'),
        NetKind.cellular,
      );
    });

    test('루프백/공인 IP는 none', () {
      expect(NetworkClassifier.classify('lo', '127.0.0.1'), NetKind.none);
      expect(NetworkClassifier.classify('wlan0', '8.8.8.8'), NetKind.none);
      expect(NetworkClassifier.classify('wlan0', '169.254.1.1'), NetKind.none);
    });
  });
}
