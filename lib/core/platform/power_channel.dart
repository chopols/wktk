/// 전원(포그라운드 서비스) 제어 · 백그라운드 호출 채널.
///
/// Android 네이티브(`PowerController`/`WktkPowerService`)와 통신한다.
/// iOS 등 플러그인이 없는 환경에서는 예외를 삼키고 `false`를 돌려주어
/// 앱 동작 자체는 계속되도록 한다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class PowerChannel {
  static const MethodChannel _channel = MethodChannel('wktk/power');

  /// 전원 ON/OFF 스위치.
  ///
  /// - `true` : 백그라운드 대기를 위한 포그라운드 서비스를 기동한다.
  /// - `false`: 서비스를 정지하고 **프로세스를 완전히 종료**한다.
  static Future<bool> setPower(bool on) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setPower', {'on': on});
      return ok ?? false;
    } catch (e) {
      debugPrint('전원 제어 실패(플러그인 없음/예외): $e');
      return false;
    }
  }

  /// 전원(포그라운드 서비스) 가동 여부.
  static Future<bool> isPowerOn() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isPowerOn');
      return ok ?? false;
    } catch (e) {
      debugPrint('전원 상태 조회 실패: $e');
      return false;
    }
  }

  /// 백그라운드 대기 중 상대 PTT 감지 → 헤드업 알림 + 진동 + 포그라운드 전화.
  static Future<void> ring({String? talker, int? channel}) async {
    try {
      await _channel.invokeMethod<void>('ring', {
        'talker': talker,
        'channel': channel,
      });
    } catch (e) {
      debugPrint('백그라운드 전화 실패: $e');
    }
  }
}
