/// Android MulticastLock MethodChannel 래퍼.
///
/// Windows/iOS 등 미지원 플랫폼이나 플러그인 부재 시 false/빈 동작으로 안전하게 처리.
library;

import 'package:flutter/services.dart';

class MulticastLockChannel {
  MulticastLockChannel._();

  static const MethodChannel _channel = MethodChannel('wktk/multicast');

  static Future<bool> acquire() async {
    try {
      return await _channel.invokeMethod<bool>('acquire') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (_) {
      // 무시
    }
  }
}
