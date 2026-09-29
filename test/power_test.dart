import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wktk/app/theme.dart';
import 'package:wktk/core/network/network_monitor.dart';
import 'package:wktk/features/walkie/presentation/walkie_controller.dart';
import 'package:wktk/features/walkie/presentation/walkie_screen.dart';
import 'package:wktk/features/walkie/presentation/widgets/power_button.dart';

/// 테스트에서 네트워크 인터페이스 조회(3초 주기 타이머)를 없애기 위한 스텁.
class _NoopNetworkMonitor extends NetworkMonitor {
  @override
  NetworkStatus build() => NetworkStatus.disconnected;
}

void main() {
  late ProviderContainer container;

  /// 무전기 화면에는 점멸 LED 등 무한 애니메이션이 있어 pumpAndSettle 이 타임아웃한다.
  /// 다이얼로그 전환만 필요한 만큼만 진행시킨다.
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpWalkie(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [networkStatusProvider.overrideWith(_NoopNetworkMonitor.new)],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WalkieScreen()),
      ),
    );
    await tester.pump();
  }

  group('PowerButton 위젯', () {
    testWidgets('ON이면 붉은 전원 아이콘이 눌리면 콜백이 호출된다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PowerButton(on: true, onPressed: () => taps++)),
        ),
      );

      expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
      expect(find.bySemanticsLabel('전원 끄기'), findsOneWidget);
      await tester.tap(find.byType(PowerButton));
      expect(taps, 1);
    });

    testWidgets('OFF이면 소등 색상(회색)이다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PowerButton(on: false, onPressed: () {})),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.power_settings_new));
      expect(icon.color, AppColors.textLow);
      expect(find.bySemanticsLabel('전원 켜기'), findsOneWidget);
    });
  });

  group('무전기 화면 전원 스위치', () {
    testWidgets('설정 아이콘 아래에 전원 버튼이 있고 기본값은 켜짐', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpWalkie(tester);

      expect(container.read(walkieControllerProvider).powerOn, isTrue);
      expect(find.byType(PowerButton), findsOneWidget);

      // 환경설정(설정) 버튼보다 아래에 배치된다.
      final settingsY = tester.getCenter(find.byTooltip('설정')).dy;
      final powerY = tester.getCenter(find.byType(PowerButton)).dy;
      expect(powerY, greaterThan(settingsY));
    });

    testWidgets('전원 OFF 확인 다이얼로그에서 취소하면 전원이 유지된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpWalkie(tester);

      await tester.tap(find.byType(PowerButton));
      await pumpDialog(tester);
      expect(find.text('전원을 끄시겠습니까?'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await pumpDialog(tester);
      expect(container.read(walkieControllerProvider).powerOn, isTrue);
    });

    testWidgets('전원 끄기를 확정하면 전원이 꺼진다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpWalkie(tester);

      await tester.tap(find.byType(PowerButton));
      await pumpDialog(tester);

      await tester.tap(find.widgetWithText(FilledButton, '전원 끄기'));
      await pumpDialog(tester);

      expect(container.read(walkieControllerProvider).powerOn, isFalse);
    });
  });
}
