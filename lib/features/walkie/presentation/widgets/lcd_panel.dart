/// 무전기 LCD 디스플레이 창.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/network_monitor.dart' show NetKind;
import '../../domain/walkie_state.dart';
import 'peer_list_sheet.dart';
import 'seven_seg_number.dart';

class LcdPanel extends StatelessWidget {
  const LcdPanel({super.key, required this.state});

  final WalkieUiState state;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state.txStatus) {
      TxStatus.idle => 'IDLE · 대기',
      TxStatus.transmitting => 'TX · 송신',
      TxStatus.receiving => 'RX · ${state.talkerNickname ?? '수신'}',
      TxStatus.busy => 'CH BUSY · 채널 사용 중',
      TxStatus.collision => 'COLLISION · 충돌',
    };
    final statusColor = switch (state.txStatus) {
      TxStatus.transmitting => AppColors.accent,
      TxStatus.receiving => AppColors.rxGreen,
      TxStatus.busy => AppColors.txRed,
      TxStatus.collision => AppColors.txRed,
      _ => AppColors.lcdTextDim,
    };

    return Container(
      height: 196,
      decoration: BoxDecoration(
        color: AppColors.lcdBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0xFF3A5548).withValues(alpha: 0.35),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // 액정 배경 (그리드 + 노이즈)
            Positioned.fill(
              child: CustomPaint(
                painter: _LcdBackdropPainter(seed: state.channel),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 좌측: 채널 번호
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lcdLabel('채널'),
                          const SizedBox(height: 2),
                          SevenSegNumber(
                            text: state.channel.toString().padLeft(2, '0'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // 우측: 상태 라인
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            statusText,
                            style: _lcdText(statusColor, 13, bold: true),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => showPeerListSheet(
                              context,
                              peers: state.peers,
                              localNickname: state.localNickname,
                              channel: state.channel,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_alt_outlined,
                                  size: 11,
                                  color: AppColors.lcdTextDim,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '접속 ${state.peerCount}대',
                                  style: _lcdText(AppColors.lcdTextDim, 12)
                                      .copyWith(
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.lcdTextDim,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.graphic_eq,
                                  size: 11,
                                  color: AppColors.lcdTextDim,
                                ),
                              ),
                              LevelMeter(level: state.signalLevel, width: 92),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ME ${state.localNickname}',
                            style: _lcdText(AppColors.lcdTextDim, 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _lcdLabel('SYS'),
                      const SizedBox(width: 8),
                      Text(
                        'WKTK-1  v1.0',
                        style: _lcdText(AppColors.lcdTextDim, 9),
                      ),
                      const Spacer(),
                      _lcdLabel(
                        state.wifiOk
                            ? (state.netKind == NetKind.cellular
                                  ? 'CELLULAR'
                                  : 'WIFI OK')
                            : 'NO WIFI',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Wi-Fi 미연결 오버레이
            if (!state.wifiOk)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Text(
                      'Wi-Fi 미연결\n송수신 비활성화',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.txRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _lcdLabel(String s) => Text(
    s,
    style: TextStyle(
      color: AppColors.lcdTextDim,
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
    ),
  );

  TextStyle _lcdText(Color color, double size, {bool bold = false}) =>
      TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontFamily: 'monospace',
        letterSpacing: 0.5,
      );
}

/// LCD 특유의 어두운 그리드 + 노이즈 텍스처 배경.
class _LcdBackdropPainter extends CustomPainter {
  const _LcdBackdropPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // 기본 톤
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2721), Color(0xFF232E28)],
        ).createShader(Offset.zero & size),
    );

    // 미세 그리드
    final grid = Paint()
      ..color = AppColors.lcdGrid
      ..strokeWidth = 1;
    const step = 8.0;
    for (var gx = 0.0; gx <= size.width; gx += step) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), grid);
    }
    for (var gy = 0.0; gy <= size.height; gy += step) {
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }

    // 시드 노이즈: 스캔라인 느낌의 어두운 점
    final rnd = math.Random(seed * 7919 + 11);
    final dot = Paint();
    for (var i = 0; i < 140; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      dot.color = Colors.black.withValues(
        alpha: 0.10 + rnd.nextDouble() * 0.20,
      );
      canvas.drawCircle(Offset(x, y), 0.6, dot);
    }

    // 비네트
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.30),
              ],
            ).createShader(
              Rect.fromCenter(
                center: size.center(Offset.zero),
                width: size.width * 1.1,
                height: size.height * 0.9,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _LcdBackdropPainter old) => old.seed != seed;
}

/// 신호 레벨 바 미터.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level, this.width = 92});

  final double level; // 0..1
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 12),
      painter: _LevelMeterPainter(level: level),
    );
  }
}

class _LevelMeterPainter extends CustomPainter {
  const _LevelMeterPainter({required this.level});

  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 14;
    final gap = 2.0;
    final barW = (size.width - gap * (bars - 1)) / bars;
    final filled = (level.clamp(0, 1) * bars).round();

    for (var i = 0; i < bars; i++) {
      final t = i / bars;
      // 상단부터 채움
      final isFull = i < filled;
      final color = t < 0.6
          ? AppColors.rxGreen.withValues(alpha: isFull ? 1 : 0.15)
          : t < 0.85
          ? AppColors.accent.withValues(alpha: isFull ? 1 : 0.15)
          : AppColors.txRed.withValues(alpha: isFull ? 1 : 0.15);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(i * (barW + gap), 0, barW, size.height),
          topLeft: const Radius.circular(1.5),
          topRight: const Radius.circular(1.5),
          bottomLeft: const Radius.circular(1.5),
          bottomRight: const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelMeterPainter old) =>
      (old.level - level).abs() > 0.001;
}
