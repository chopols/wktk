/// 상태 LED: 대기(녹색 점멸) / 송신(빨강) / 수신(초록).
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

enum LedState { idle, tx, rx }

class StatusLedWidget extends StatefulWidget {
  const StatusLedWidget({
    super.key,
    this.state = LedState.idle,
    this.size = 22,
  });

  final LedState state;
  final double size;

  @override
  State<StatusLedWidget> createState() => _StatusLedWidgetState();
}

class _StatusLedWidgetState extends State<StatusLedWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.state == LedState.idle) {
      _blink.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StatusLedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == LedState.idle && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (widget.state != LedState.idle && _blink.isAnimating) {
      _blink.stop();
      _blink.value = 1;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.state) {
      LedState.idle => '대기',
      LedState.tx => '송신',
      LedState.rx => '수신',
    };
    return Semantics(
      label: label,
      child: AnimatedBuilder(
        animation: _blink,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LedPainter(
            color: switch (widget.state) {
              LedState.tx => AppColors.txRed,
              LedState.rx => AppColors.rxGreen,
              LedState.idle => AppColors.idleGreenDim,
            },
            intensity: switch (widget.state) {
              LedState.idle => 0.4 + 0.6 * _blink.value,
              _ => 1.0,
            },
            lit: widget.state != LedState.idle || _blink.value > 0.4,
          ),
        ),
      ),
    );
  }
}

class _LedPainter extends CustomPainter {
  const _LedPainter({
    required this.color,
    required this.intensity,
    required this.lit,
  });

  final Color color;
  final double intensity;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // 소켓 (오목한 홈)
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4A4E52), Color(0xFF101214)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // 렌즈 외곽 링
    canvas.drawCircle(
      center,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = const Color(0xFF0B0C0E),
    );

    // 발광부
    if (lit) {
      final glowR = r * (0.8 + 0.5 * intensity);
      canvas.drawCircle(
        center,
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.5 * intensity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: glowR)),
      );
      canvas.drawCircle(
        center,
        r * 0.6,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.9), color],
          ).createShader(Rect.fromCircle(center: center, radius: r * 0.6)),
      );
      // 하이라이트
      canvas.drawCircle(
        center - Offset(r * 0.18, r * 0.18),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    } else {
      canvas.drawCircle(
        center,
        r * 0.6,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r * 0.6)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LedPainter old) =>
      old.color != color ||
      (old.intensity - intensity).abs() > 0.01 ||
      old.lit != lit;
}
