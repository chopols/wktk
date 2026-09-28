/// 상단 안테나 디테일. 송신 중 끝단에 앰버 글로우가 펄스한다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class AntennaWidget extends StatefulWidget {
  const AntennaWidget({super.key, this.transmitting = false});

  final bool transmitting;

  @override
  State<AntennaWidget> createState() => _AntennaWidgetState();
}

class _AntennaWidgetState extends State<AntennaWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    _sync(widget.transmitting);
  }

  @override
  void didUpdateWidget(covariant AntennaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(widget.transmitting);
  }

  void _sync(bool tx) {
    if (tx && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!tx && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Semantics(
      label: widget.transmitting ? '안테나: 송신 중' : '안테나',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: Size(w, 34),
          painter: _AntennaPainter(
            transmitting: widget.transmitting,
            pulse: _pulse.value,
          ),
        ),
      ),
    );
  }
}

class _AntennaPainter extends CustomPainter {
  const _AntennaPainter({required this.transmitting, required this.pulse});

  final bool transmitting;
  final double pulse; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final topTipY = size.height * 0.16;
    final baseY = size.height * 0.86;
    final mastHalf = size.width * 0.055;

    // 송신 글로우
    if (transmitting) {
      final glow = 0.55 + 0.35 * math.sin(pulse * math.pi);
      final radius = size.width * (0.05 + 0.02 * pulse);
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.accent.withValues(alpha: glow),
                AppColors.accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(centerX, topTipY),
                radius: radius * 3,
              ),
            );
      canvas.drawCircle(Offset(centerX, topTipY), radius * 3, paint);
    }

    // 안테나 바디: 위로 갈수록 가늘어지는 다각형
    final body = Path()
      ..moveTo(centerX - mastHalf, baseY)
      ..lineTo(centerX - mastHalf * 0.55, baseY - size.height * 0.18)
      ..lineTo(centerX - mastHalf * 0.32, topTipY + size.height * 0.14)
      ..lineTo(centerX + mastHalf * 0.32, topTipY + size.height * 0.14)
      ..lineTo(centerX + mastHalf * 0.55, baseY - size.height * 0.18)
      ..lineTo(centerX + mastHalf, baseY)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0E1013), Color(0xFF2E343C)],
        ).createShader(Rect.fromLTWH(0, topTipY, size.width, size.height)),
    );

    // 마운트 베이스
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY + size.height * 0.07),
          width: size.width * 0.16,
          height: size.height * 0.12,
        ),
        Radius.circular(size.height * 0.04),
      ),
      Paint()..color = AppColors.surfaceHigh,
    );

    // 링 밴드 (2개)
    final bandPaint = Paint()..color = AppColors.surfaceHigh;
    final bandY1 = baseY - size.height * 0.10;
    canvas.drawRect(
      Rect.fromLTWH(
        centerX - mastHalf,
        bandY1,
        mastHalf * 2,
        size.height * 0.05,
      ),
      bandPaint,
    );

    // 끝단 팁 (전도부) — 송신 시 앰버 점등
    final tipColor = transmitting
        ? AppColors.accent.withValues(alpha: 0.55 + 0.45 * pulse)
        : AppColors.textLow;
    canvas.drawCircle(
      Offset(centerX, topTipY),
      mastHalf * 0.6,
      Paint()..color = tipColor,
    );
  }

  @override
  bool shouldRepaint(covariant _AntennaPainter old) =>
      old.transmitting != transmitting || (old.pulse - pulse).abs() > 0.001;
}
