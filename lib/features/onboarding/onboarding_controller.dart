/// 온보딩(권한 요청) 컨트롤러 + 첫 실행 분기 Provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/kv_store.dart';

enum OnboardingStep { idle, requesting, denied, permanentlyDenied, done }

class OnboardingController extends Notifier<OnboardingStep> {
  @override
  OnboardingStep build() => OnboardingStep.idle;

  /// 마이크 권한 요청 → 성공 시 온보딩 완료 처리.
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
