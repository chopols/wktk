/// 첫 실행 온보딩: 마이크 권한 요청, 거부 시 설정 안내.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../walkie/presentation/widgets/status_led_widget.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.2,
            colors: [AppColors.body.withValues(alpha: 0.9), AppColors.bodyDeep],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'WKTK',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '서버 없는 워키토키',
                      style: TextStyle(
                        color: AppColors.textMid,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const StatusLedWidget(state: LedState.idle, size: 28),
                    const SizedBox(height: 28),
                    Text(
                      '같은 Wi-Fi(LAN)에 있는 친구와\n서버 없이 무전기처럼 대화하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMid.withValues(alpha: 0.9),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _StepBoard(),
                    const SizedBox(height: 24),
                    switch (step) {
                      OnboardingStep.requesting => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      OnboardingStep.denied ||
                      OnboardingStep.permanentlyDenied => _DeniedCard(
                        permanently: step == OnboardingStep.permanentlyDenied,
                        onRetry: controller.requestMicAndStart,
                        onSettings: controller.openSystemSettings,
                      ),
                      _ => Column(
                        children: [
                          FilledButton(
                            onPressed: controller.requestMicAndStart,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: const Color(0xFF1B1205),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: const Text('시작하기'),
                          ),
                        ],
                      ),
                    },
                    const SizedBox(height: 20),
                    Text(
                      '마이크와 로컬 네트워크(LAN) 사용 권한이 필요합니다.\n'
                      '기록된 음성은 기기 밖으로 나가지 않습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLow.withValues(alpha: 0.85),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBoard extends StatelessWidget {
  const _StepBoard();

  static const _items = [
    (Icons.mic, '마이크 권한'),
    (Icons.wifi, '같은 Wi-Fi 연결'),
    (Icons.radio, '같은 채널 선택'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceHigh, width: 1),
      ),
      child: Column(
        children: [
          for (final (icon, label) in _items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DeniedCard extends StatelessWidget {
  const _DeniedCard({
    required this.permanently,
    required this.onRetry,
    required this.onSettings,
  });

  final bool permanently;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final message = permanently
        ? '마이크 권한이 차단되어 있어요.\n설정에서 직접 허용해 주세요.'
        : '마이크 권한이 없으면 송신할 수 없어요.\n다시 요청하거나 설정에서 허용해 주세요.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.txRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.txRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mic_off, color: AppColors.txRed, size: 26),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textHi,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!permanently)
                OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.txRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('설정에서 열기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
