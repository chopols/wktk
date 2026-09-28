/// 앱 최상위 화면 분기 라우터.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_controller.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/walkie/presentation/walkie_screen.dart';

/// 첫 실행 여부에 따라 온보딩 ↔ 무전기 화면을 분기한다.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(onboardingDoneProvider);
    return done.when(
      data: (v) => v ? const WalkieScreen() : const OnboardingScreen(),
      loading: () => const Scaffold(body: SizedBox.expand()),
      error: (_, _) => const WalkieScreen(),
    );
  }
}
