import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wktk/core/network/network_monitor.dart';
import 'package:wktk/features/settings/presentation/settings_screen.dart';
import 'package:wktk/features/settings/settings_controller.dart';
import 'package:wktk/features/walkie/presentation/walkie_controller.dart';

/// 테스트용 무음 네트워크 모니터: 타이머 없이 '연결 안 됨' 고정.
class _NoopNetworkMonitor extends NetworkMonitor {
  @override
  NetworkStatus build() => NetworkStatus.disconnected;
}

void main() {
  late ProviderContainer container;

  Future<void> pumpSettings(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [networkStatusProvider.overrideWith(_NoopNetworkMonitor.new)],
    );
    addTearDown(container.dispose);

    // 설정 화면 전체(아래 섹션 포함)가 보이도록 큰 뷰포트 사용.
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('설정 화면: 모든 섹션이 표시된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);

    expect(find.text('닉네임'), findsOneWidget);
    expect(find.text('기본 채널'), findsOneWidget);
    expect(find.text('효과음'), findsOneWidget);
    expect(find.text('햅틱'), findsOneWidget);
    expect(find.text('VOX'), findsOneWidget);
    expect(find.text('수신 노이즈 게이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('시스템'), findsOneWidget);
  });

  testWidgets('효과음/햅틱을 끄면 상태가 반영된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);

    expect(container.read(walkieControllerProvider).effectsEnabled, isTrue);
    await tester.tap(find.text('효과음'));
    await tester.pump();
    expect(container.read(walkieControllerProvider).effectsEnabled, isFalse);

    await tester.tap(find.text('햅틱'));
    await tester.pump();
    expect(container.read(walkieControllerProvider).hapticsEnabled, isFalse);
  });

  testWidgets('VOX를 켜면 상태가 반영된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);

    expect(container.read(walkieControllerProvider).voxEnabled, isFalse);
    await tester.tap(find.text('VOX'));
    await tester.pump();
    expect(container.read(walkieControllerProvider).voxEnabled, isTrue);
  });

  testWidgets('닉네임을 저장하면 prefs와 상태에 반영된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);

    await tester.enterText(find.byType(TextField), '홍길동');
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(container.read(walkieControllerProvider).localNickname, '홍길동');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nickname'), '홍길동');
  });

  testWidgets('테마를 라이트로 바꾸면 provider에 반영된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);

    expect(
      container.read(themeModeControllerProvider).value,
      AppThemeMode.dark,
    );
    await tester.tap(find.text('라이트'));
    await tester.pump();
    expect(
      container.read(themeModeControllerProvider).value,
      AppThemeMode.light,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });

  testWidgets('기본 채널이 저장된 값으로 시작된다', (tester) async {
    SharedPreferences.setMockInitialValues({'default_channel': 7});
    await pumpSettings(tester);

    // _loadPersistedSettings가 prefs의 채널을 상태에 반영.
    expect(container.read(walkieControllerProvider).channel, 7);
  });
}