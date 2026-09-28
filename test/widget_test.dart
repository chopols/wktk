import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wktk/main.dart';

void main() {
  testWidgets('첫 실행이면 온보딩 화면이 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: WktkApp()));
    await tester.pump();
    expect(find.text('WKTK'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('온보딩 완료 상태면 무전기 화면이 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(const ProviderScope(child: WktkApp()));
    await tester.pump();
    expect(find.text('WKTK'), findsOneWidget);
    expect(find.text('대기'), findsOneWidget);
  });
}
