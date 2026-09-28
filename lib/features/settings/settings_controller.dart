/// 설정 도메인: 테마 모드 + 영속화 컨트롤러.
///
/// Step 6: 테마(다크/라이트/시스템) 선택. 나머지 설정(닉네임/채널/볼륨/효과음/햅틱/VOX/
/// 노이즈 게이트)은 무전기 컨트롤러가 직접 영속화하며, 설정 화면이 같은 상태를 공유한다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/kv_store.dart';

/// 앱 테마 모드. 'android:forceDarkAllowed' 같은 플랫폼 정책은 없으므로
/// [AppThemeMode.byName] 변환만 지원한다.
enum AppThemeMode { dark, light, system }

class ThemeModeController extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() async => _fromName(await AppPrefs.themeMode());

  Future<void> set(AppThemeMode mode) async {
    await AppPrefs.setThemeMode(mode.name);
    state = AsyncData(mode);
  }
}

AppThemeMode _fromName(String name) => switch (name) {
  'light' => AppThemeMode.light,
  'system' => AppThemeMode.system,
  _ => AppThemeMode.dark,
};

final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, AppThemeMode>(
      ThemeModeController.new,
    );
