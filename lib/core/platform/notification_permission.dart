/// 알림(POST_NOTIFICATIONS) 권한 도우미.
///
/// 전원 ON 상태 표시(상시 알림)와 상대 PTT 전화 알림에 필요하다.
/// Android 13+에서만 동작하며, 거부해도 앱 기능 자체는 막히지 않는다.
library;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

abstract final class NotificationPermission {
  /// 프로세스당 1회만 요청한다(앱 재시작 시 다시 물어보지 않음).
  static bool _requested = false;

  /// 필요 시 알림 권한을 요청한다. 허용 여부를 반환한다.
  static Future<bool> ensure() async {
    if (_requested) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    _requested = true;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      // 영구 거부 상태는 시스템 설정에서만 바꿀 수 있어 다시 묻지 않는다.
      if (status.isPermanentlyDenied || status.isRestricted) return false;
      return (await Permission.notification.request()).isGranted;
    } catch (_) {
      // 미지원 플랫폼/채널 부재는 무시한다(전원 기능은 알림 없이도 동작).
      return false;
    }
  }
}
