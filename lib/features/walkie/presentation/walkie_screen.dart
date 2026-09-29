import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/walkie_state.dart';
import 'walkie_controller.dart';
import 'widgets/antenna_widget.dart';
import 'widgets/lcd_panel.dart';
import 'widgets/peer_list_sheet.dart';
import 'widgets/power_button.dart';
import 'widgets/ptt_button.dart';
import 'widgets/rotary_knob.dart';
import 'widgets/speaker_grille_widget.dart';
import 'widgets/status_banner.dart';
import 'widgets/status_led_widget.dart';

class WalkieScreen extends ConsumerWidget {
  const WalkieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walkieUiProvider);
    final controller = ref.read(walkieControllerProvider.notifier);
    final tx = state.txStatus == TxStatus.transmitting;
    final rx = state.txStatus == TxStatus.receiving;

    // 백그라운드 대기 중 상대가 PTT를 눌러 전화를 걸어 온 경우.
    ref.listen<String?>(
      walkieControllerProvider.select((s) => s.incomingCaller),
      (prev, next) {
        if (next == null || next.isEmpty) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text('$next 님이 전화를 걸었습니다'),
          ),
        );
      },
    );

    final String? sessionError = state.sessionError;
    final StatusBanner? banner = sessionError != null
        ? StatusBanner(
            icon: Icons.error_outline,
            color: AppColors.txRed,
            message: '연결 실패: $sessionError',
            actionLabel: '다시 시도',
            onAction: controller.retrySession,
          )
        : state.wifiOk == false
        ? StatusBanner(
            icon: Icons.wifi_off,
            color: AppColors.txRed,
            message: 'Wi-Fi 미연결 — 송수신이 비활성화됩니다',
            actionLabel: '설정',
            onAction: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          )
        : state.txStatus == TxStatus.collision
        ? const StatusBanner(
            icon: Icons.warning_amber_rounded,
            color: AppColors.txRed,
            message: '충돌 감지 — PTT를 놓고 잠시 후 다시 시도해 주세요',
          )
        : state.txStatus == TxStatus.busy
        ? const StatusBanner(
            icon: Icons.block,
            color: AppColors.accent,
            message: '채널 사용 중 — 상대 통화가 끝나면 송신할 수 있어요',
          )
        : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.2,
            colors: [AppColors.body.withValues(alpha: 0.9), AppColors.bodyDeep],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'WKTK',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    // 환경설정 바로 아래 붉은 전원 버튼
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '설정',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.tune,
                            color: AppColors.textLow,
                          ),
                        ),
                        PowerButton(
                          on: state.powerOn,
                          onPressed: () =>
                              _confirmPowerOff(context, controller),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 안테나
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AntennaWidget(transmitting: tx),
              ),
              // 상태 LED 행
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusLedWidget(
                      state: switch (state.txStatus) {
                        TxStatus.transmitting => LedState.tx,
                        TxStatus.receiving => LedState.rx,
                        _ => LedState.idle,
                      },
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      switch (state.txStatus) {
                        TxStatus.idle => '대기',
                        TxStatus.transmitting => '송신 중',
                        TxStatus.receiving =>
                          '${state.talkerNickname ?? '수신'} 목소리',
                        TxStatus.busy => '채널 사용 중',
                        TxStatus.collision => '충돌',
                      },
                      style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // LCD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: LcdPanel(state: state),
              ),
              const SizedBox(height: 10),
              // 안내 배너
              if (banner != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: banner,
                ),
              const SizedBox(height: 6),
              // 스피커 + 노브
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SpeakerGrilleWidget(
                            rms: rx ? state.signalLevel : 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RotaryKnob(
                              value: state.volume,
                              notches: 20,
                              label: '볼륨',
                              unit: '%',
                              diameter: 92,
                              onChanged: controller.setVolume,
                              onNotch: controller.knobTick,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'VOL',
                              style: TextStyle(
                                color: AppColors.textLow,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            RotaryKnob(
                              value: (state.channel - 1) / 15,
                              notches: 16,
                              label: '채널',
                              unit: '',
                              diameter: 92,
                              onNotch: controller.knobTick,
                              onChanged: (v) =>
                                  controller.setChannel((v * 15).round() + 1),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'CH',
                              style: TextStyle(
                                color: AppColors.textLow,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // PTT + 상태
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (!state.wifiOk) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Wi-Fi에 연결되어 있지 않습니다'),
                                ),
                              );
                              return;
                            }
                            await controller.checkConnection();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('접속을 다시 확인합니다')),
                            );
                          },
                          icon: const Icon(Icons.refresh, size: 15),
                          label: const Text(
                            '접속\n확인',
                            textAlign: TextAlign.center,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accentDim),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PttButton(
                      transmitting: tx,
                      onPressStart: controller.pttDown,
                      onPressEnd: controller.pttUp,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => showPeerListSheet(
                              context,
                              peers: state.peers,
                              localNickname: state.localNickname,
                              channel: state.channel,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people_alt_outlined,
                                    size: 13,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '접속 ${state.peerCount}대',
                                    style: const TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.textLow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'CH ${state.channel.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.textLow,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// 전원 OFF 확인 → 확정 시 세션/서비스를 정리하고 프로세스를 완전히 종료한다.
  Future<void> _confirmPowerOff(
    BuildContext context,
    WalkieController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '전원을 끄시겠습니까?',
          style: TextStyle(
            color: AppColors.textHi,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: const Text(
          '앱 프로세스가 완전히 종료됩니다.\n'
          '백그라운드 대기·자동 전화가 모두 멈춥니다.\n'
          '다시 사용하려면 앱을 직접 실행해 주세요.',
          style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.power_settings_new, size: 18),
            label: const Text('전원 끄기'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.txRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.powerOff();
  }
}
