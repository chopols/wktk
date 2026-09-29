/// 온보딩(권한 요청) 컨트롤러 + 첫 실행 분기 Provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/notification_permission.dart';
import '../../core/utils/kv_store.dart';

enum OnboardingStep { idle, requesting, denied, permanentlyDenied, done }

class OnboardingController extends Notifier<OnboardingStep> {
  @override
  OnboardingStep build() => OnboardingStep.idle;

  /// 마이크 권한 요청 → 성공 시 온보딩 완료 처리.
  ///
  /// 알림(POST_NOTIFICATIONS) 권한은 전원 상시 알림·상대 호출 알림에 쓰이므로 함께
  /// 요청하되, 거부해도 앱 동작에는 영향이 없어 완료 판정에는 영향을 주지 않는다.
  Future<OnboardingStep> requestMicAndStart() async {
    state = OnboardingStep.requesting;
    final status = await Permission.microphone.request();
    final step = switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited => OnboardingStep.done,
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted => OnboardingStep.permanentlyDenied,
      _ => OnboardingStep.denied,
    };
    state = step;
    if (step == OnboardingStep.done) {
      await NotificationPermission.ensure();
      await AppPrefs.setOnboardingDone(true);
      ref.invalidate(onboardingDoneProvider);
    }
    return step;
  }

  /// 설정 앱으로 이동 (거부/영구거부 시).
  Future<void> openSystemSettings() => openAppSettings();
}

/// 첫 실행 완료 여부 (AppGate 분기 + 온보딩 완료 시 invalidate).
final onboardingDoneProvider = FutureProvider<bool>(
  (ref) => AppPrefs.onboardingDone(),
);

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingStep>(
      OnboardingController.new,
    );
