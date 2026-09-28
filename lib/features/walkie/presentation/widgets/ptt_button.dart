/// PTT 누름 버튼. 눌림/송신 상태를 시각화(와이어-리모컨 무전기 스타일).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    this.transmitting = false,
    this.onPressStart,
    this.onPressEnd,
    this.diameter = 118,
  });

  final bool transmitting;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final double diameter;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync(widget.transmitting);
  }

  @override
  void didUpdateWidget(covariant PttButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(widget.transmitting);
  }

  void _sync(bool tx) {
    if (tx && !_ring.isAnimating) {
      _ring.repeat();
    } else if (!tx && _ring.isAnimating) {
      _ring.stop();
      _ring.value = 0;
    }
  }

  void _down() {
    setState(() => _pressed = true);
    widget.onPressStart?.call();
  }

  void _up() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onPressEnd?.call();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.transmitting ? 'PTT: 송신 중, 눌러서 종료' : 'PTT: 눌러서 송신',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, _) {
              final scale = _pressed ? 0.955 : 1.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 송신 펄스 링
                  if (widget.transmitting)
                    CustomPaint(
                      size: Size.square(widget.diameter),
                      painter: _RingPainter(phase: _ring.value),
                    ),
                  Transform.translate(
                    offset: Offset(0, _pressed ? 2 : 0),
                    child: Transform.scale(
                      scale: scale,
                      child: CustomPaint(
                        size: Size.square(widget.diameter),
                        painter: _PttBodyPainter(
                          pressed: _pressed,
                          transmitting: widget.transmitting,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PTT',
                                style: TextStyle(
                                  color: widget.transmitting
                                      ? AppColors.accent
                                      : AppColors.textHi,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _pressed
                                    ? 'TALKING'
                                    : widget.transmitting
                                    ? 'TALKING…'
                                    : 'PRESS',
                                style: TextStyle(
                                  color: (_pressed || widget.transmitting)
                                      ? AppColors.accent
                                      : AppColors.textLow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 * (0.9 + 0.35 * phase);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: (1 - phase) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 2 * phase;
    canvas.drawCircle(c, maxR, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      (old.phase - phase).abs() > 0.001;
}

class _PttBodyPainter extends CustomPainter {
  const _PttBodyPainter({required this.pressed, required this.transmitting});

  final bool pressed;
  final bool transmitting;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // 송신 시 주변 앰버 글로우
    if (transmitting) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.30),
              AppColors.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // 본체
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.3, -0.45),
          radius: 1.15,
          colors: pressed
              ? const [Color(0xFF2A2E34), Color(0xFF17191C)]
              : const [Color(0xFF3B414A), Color(0xFF1C1F24)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // 림
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.surfaceHigh,
    );
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.bodyDeep,
    );

    // 베벨 하이라이트 (박스 안쪽 그림자 흉내)
    final topArc = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      topArc,
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: pressed ? 0.06 : 0.14),
    );

    // 상단 작은 눌림 캡 (일체형돔)
    canvas.drawCircle(
      c.translate(0, -r * 0.02),
      r * 0.78,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.0,
          colors: pressed
              ? const [Color(0xFF22262B), Color(0xFF15171A)]
              : const [Color(0xFF31363E), Color(0xFF191C20)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.78)),
    );
    canvas.drawCircle(
      c.translate(0, -r * 0.02),
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.surfaceHigh.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _PttBodyPainter old) =>
      old.pressed != pressed || old.transmitting != transmitting;
}
