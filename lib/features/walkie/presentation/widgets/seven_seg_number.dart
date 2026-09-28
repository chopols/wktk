/// 7-세그먼트 숫자 표시 (CustomPainter 기반, 이미지/폰트 불필요).
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// 한 자리를 그리기 위한 세그먼트 정의.
class SevenSegDrawer {
  SevenSegDrawer._();

  /// 세그먼트 온/오프 테이블 (a b c d e f g)
  static const List<List<int>> _chars = [
    [1, 1, 1, 1, 1, 1, 0], // 0
    [0, 1, 1, 0, 0, 0, 0], // 1
    [1, 1, 0, 1, 1, 0, 1], // 2
    [1, 1, 1, 1, 0, 0, 1], // 3
    [0, 1, 1, 0, 0, 1, 1], // 4
    [1, 0, 1, 1, 0, 1, 1], // 5
    [1, 0, 1, 1, 1, 1, 1], // 6
    [1, 1, 1, 0, 0, 0, 0], // 7
    [1, 1, 1, 1, 1, 1, 1], // 8
    [1, 1, 1, 1, 0, 1, 1], // 9
  ];

  static List<int>? segmentsFor(int digit) =>
      digit >= 0 && digit < _chars.length ? _chars[digit] : null;

  static RRect _seg({
    required double x,
    required double y,
    required double w,
    required double h,
    required double t,
  }) {
    return RRect.fromRectAndCorners(
      Rect.fromLTWH(x, y, w, h),
      topLeft: Radius.circular(t / 2),
      topRight: Radius.circular(t / 2),
      bottomLeft: Radius.circular(t / 2),
      bottomRight: Radius.circular(t / 2),
    );
  }

  /// digitHeight 기준으로 한 자리를 [topLeft]에서 그린다.
  static void paintDigit(
    Canvas canvas,
    int digit, {
    required Offset topLeft,
    required double digitHeight,
    required Color onColor,
    required Color offColor,
  }) {
    final w = digitHeight * 0.58;
    final t = digitHeight * 0.12;
    final x = topLeft.dx;
    final y = topLeft.dy;
    final mid = (digitHeight) * 0.5;
    final inset = t * 0.45;

    final points = {
      'a': _seg(x: x + t * 0.5, y: y, w: w - t, h: t, t: t),
      'b': _seg(x: x + w - t, y: y + inset, w: t, h: mid - inset, t: t),
      'c': _seg(x: x + w - t, y: y + mid + inset, w: t, h: mid - inset, t: t),
      'd': _seg(x: x + t * 0.5, y: y + digitHeight - t, w: w - t, h: t, t: t),
      'e': _seg(x: x, y: y + mid + inset, w: t, h: mid - inset, t: t),
      'f': _seg(x: x, y: y + inset, w: t, h: mid - inset, t: t),
      'g': _seg(x: x + t * 0.5, y: y + mid - t * 0.5, w: w - t, h: t, t: t),
    };

    const order = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    final segs = segmentsFor(digit) ?? const [0, 0, 0, 0, 0, 0, 0];
    for (var i = 0; i < order.length; i++) {
      final on = segs[i] == 1;
      canvas.drawRRect(
        points[order[i]]!,
        Paint()..color = on ? onColor : offColor,
      );
    }
  }
}

/// 여러 자리를 오른쪽 정렬로 그리는 위젯.
class SevenSegNumber extends StatelessWidget {
  const SevenSegNumber({
    super.key,
    required this.text,
    this.height = 72,
    this.glow = true,
    this.onColor = AppColors.lcdText,
    this.offColor = const Color(0xFF21402E),
  });

  final String text;
  final double height;
  final bool glow;
  final Color onColor;
  final Color offColor;

  @override
  Widget build(BuildContext context) {
    final glyph = text.replaceAll(RegExp(r'[^0-9]'), '');
    final w = height * 0.58 * glyph.length + height * 0.1 * (glyph.length - 1);
    return Semantics(
      label: '채널 $glyph',
      child: SizedBox(
        width: w + 8,
        height: height + 4,
        child: CustomPaint(
          size: Size(w + 8, height + 4),
          painter: _SevenSegPainter(
            glyph: glyph,
            height: height,
            onColor: onColor,
            offColor: offColor,
            glow: glow,
          ),
        ),
      ),
    );
  }
}

class _SevenSegPainter extends CustomPainter {
  const _SevenSegPainter({
    required this.glyph,
    required this.height,
    required this.onColor,
    required this.offColor,
    required this.glow,
  });

  final String glyph;
  final double height;
  final Color onColor;
  final Color offColor;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (glyph.isEmpty) return;
    final w = height * 0.58;
    final gap = height * 0.1;
    var x = size.width - (glyph.length * w + (glyph.length - 1) * gap);

    for (var i = 0; i < glyph.length; i++) {
      final digit = int.parse(glyph[i]);
      SevenSegDrawer.paintDigit(
        canvas,
        digit,
        topLeft: Offset(x, (size.height - height) / 2),
        digitHeight: height,
        onColor: onColor,
        offColor: offColor,
      );
      x += w + gap;
    }

    if (glow) {
      // 은은한 후광
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
        Paint()
          ..shader = RadialGradient(
            colors: [
              onColor.withValues(alpha: 0.10),
              onColor.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SevenSegPainter old) =>
      old.glyph != glyph || old.onColor != onColor;
}
