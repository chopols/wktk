/// 스피커 그릴. 수신 진폭(rms)에 따라 은은하게 반응한다.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class SpeakerGrilleWidget extends StatelessWidget {
  const SpeakerGrilleWidget({super.key, this.rms = 0.0});

  final double rms; // 0..1

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '스피커 그릴',
      child: CustomPaint(
        size: Size.infinite,
        painter: _GrillePainter(rms: rms),
      ),
    );
  }
}

class _GrillePainter extends CustomPainter {
  const _GrillePainter({required this.rms});

  final double rms;

  @override
  void paint(Canvas canvas, Size size) {
    // 그릴 플레이트 배경
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF262B31), Color(0xFF1A1D21)],
        ).createShader(Offset.zero & size),
    );

    const inset = 14.0;
    const padding = 8.0;
    final inner = Rect.fromLTRB(
      inset,
      padding,
      size.width - inset,
      size.height - padding,
    );
    final slotCount = 11;
    final slotGap = 4.0;
    final slotH = (inner.height - slotGap * (slotCount - 1)) / slotCount;
    final contentW = inner.width;

    for (var i = 0; i < slotCount; i++) {
      final dy = inner.top + i * (slotH + slotGap);
      final glow = rms.clamp(0, 1) * (1 - (i / slotCount));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, dy, contentW, slotH),
        Radius.circular(slotH * 0.35),
      );
      // 슬릿 홈 (어두움)
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF0C0E10), Color(0xFF2A2F36)],
          ).createShader(rect.outerRect),
      );
      // 위쪽 하이라이트 에지
      canvas.drawLine(
        Offset(rect.left + 4, rect.top + 1.2),
        Offset(rect.right - 4, rect.top + 1.2),
        Paint()
          ..color = AppColors.textLow.withValues(alpha: 0.35 + 0.4 * glow)
          ..strokeWidth = 1,
      );
    }

    // 중앙 나사 (고정 디테일) 2개
    for (final x in [size.width * 0.5 - 26, size.width * 0.5 + 26]) {
      final c = Offset(x, size.height * 0.5);
      canvas.drawCircle(c, 4, Paint()..color = AppColors.surfaceHigh);
      canvas.drawLine(
        c - const Offset(3, 0),
        c + const Offset(3, 0),
        Paint()
          ..color = const Color(0xFF0E1013)
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrillePainter old) =>
      (old.rms - rms).abs() > 0.001;
}
