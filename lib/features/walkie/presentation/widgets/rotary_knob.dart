/// 회전형 노브. 드래그로 회전, 노치 단위 스냅, 변경 시 햅틱 틱.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class RotaryKnob extends StatefulWidget {
  const RotaryKnob({
    super.key,
    this.value = 0.0,
    this.notches = 16,
    this.label = '',
    this.unit = '',
    this.diameter = 104,
    this.onChanged,
    this.onNotch,
  });

  /// 정규화된 값 (0..1)
  final double value;
  final int notches;
  final String label;
  final String unit;
  final double diameter;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onNotch;

  @override
  State<RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<RotaryKnob> {
  static const double _range = math.pi * 1.5; // -135° ~ +135°
  static const double _minAngle = -math.pi * 0.75;

  double _angle = -math.pi * 0.75;
  double _lastPointerAngle = 0;
  double _lastStep = -1;

  @override
  void initState() {
    super.initState();
    _angle = _minAngle + widget.value.clamp(0.0, 1.0) * _range;
    _lastStep = ((widget.value.clamp(0.0, 1.0) * widget.notches) / 1)
        .roundToDouble();
  }

  @override
  void didUpdateWidget(covariant RotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _angle = _minAngle + widget.value.clamp(0.0, 1.0) * _range;
      _lastStep = (widget.value.clamp(0.0, 1.0) * widget.notches)
          .roundToDouble();
    }
  }

  Offset _center(Size size) => size.center(Offset.zero);

  void _onPanDown(DragDownDetails d, Size size) {
    final c = _center(size);
    final p = d.localPosition - c;
    _lastPointerAngle = math.atan2(p.dy, p.dx);
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final c = _center(size);
    final p = d.localPosition - c;
    final current = math.atan2(p.dy, p.dx);
    var delta = current - _lastPointerAngle;
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;
    _lastPointerAngle = current;

    setState(() {
      _angle = (_angle + delta).clamp(_minAngle, _minAngle + _range);
    });

    final step = 1.0 / widget.notches;
    final stepped =
        ((_angle - _minAngle) / _range / step).roundToDouble() * step;
    if ((stepped - _lastStep).abs() > 1e-6) {
      _lastStep = stepped;
      widget.onNotch?.call();
      widget.onChanged?.call(stepped.clamp(0.0, 1.0).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Size.square(widget.diameter);
    return Semantics(
      label: widget.label,
      value: '${(widget.value * widget.notches).round()}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _onPanDown(d, size),
        onPanUpdate: (d) => _onPanUpdate(d, size),
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: CustomPaint(
            size: size,
            painter: _KnobPainter(
              angle: _angle,
              minAngle: _minAngle,
              maxAngle: _minAngle + _range,
              notches: widget.notches,
              valueFraction: (_angle - _minAngle) / _range,
            ),
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  const _KnobPainter({
    required this.angle,
    required this.minAngle,
    required this.maxAngle,
    required this.notches,
    required this.valueFraction,
  });

  final double angle;
  final double minAngle;
  final double maxAngle;
  final int notches;
  final double valueFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // 몸체 (금속 그라디언트 + 림)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.4,
          colors: [Color(0xFF3A414B), Color(0xFF1B1E22)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.bodyDeep,
    );

    // 엣지 노치 틱 (림 주위)
    final tickPaint = Paint()
      ..color = AppColors.textLow
      ..strokeWidth = 1.6;
    for (var i = 0; i < notches; i++) {
      final a = minAngle + i / notches * (maxAngle - minAngle);
      final inner = Offset(
        c.dx + math.cos(a) * r * 0.86,
        c.dy + math.sin(a) * r * 0.86,
      );
      final outer = Offset(
        c.dx + math.cos(a) * r * 0.97,
        c.dy + math.sin(a) * r * 0.97,
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // 값 아크
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.80),
      minAngle,
      (angle - minAngle).clamp(0, maxAngle - minAngle),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.9),
    );

    // 포인터
    final ptr = Offset(
      c.dx + math.cos(angle) * r * 0.62,
      c.dy + math.sin(angle) * r * 0.62,
    );
    canvas.drawLine(
      c,
      ptr,
      Paint()
        ..color = AppColors.textHi
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // 중앙 캡
    canvas.drawCircle(c, r * 0.30, Paint()..color = AppColors.surfaceHigh);
    canvas.drawCircle(
      c,
      r * 0.30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.textLow,
    );
    canvas.drawLine(
      Offset(c.dx - r * 0.12, c.dy),
      Offset(c.dx + r * 0.12, c.dy),
      Paint()
        ..color = AppColors.bodyDeep
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - r * 0.12),
      Offset(c.dx, c.dy + r * 0.12),
      Paint()
        ..color = AppColors.bodyDeep
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter old) =>
      (old.angle - angle).abs() > 0.001 ||
      old.notches != notches ||
      old.valueFraction != valueFraction;
}
