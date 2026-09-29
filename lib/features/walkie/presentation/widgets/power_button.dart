/// 붉은 전원 버튼.
///
/// 상단 환경설정(톱니) 아이콘 아래에 배치한다.
/// 전원이 켜져 있으면 붉은 점등, 꺼지면 회색으로 꺼진다.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class PowerButton extends StatelessWidget {
  const PowerButton({
    super.key,
    required this.onPressed,
    this.on = true,
    this.size = 34,
  });

  /// 전원 ON 여부 (빨간 점등/소등 표시).
  final bool on;

  /// 누를 때 실행 (전원 OFF 확인 다이얼로그 등).
  final VoidCallback onPressed;

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.txRed : AppColors.textLow;
    return Semantics(
      button: true,
      label: on ? '전원 끄기' : '전원 켜기',
      child: Tooltip(
        message: on ? '전원 끄기 — 앱을 완전히 종료합니다' : '전원 켜기',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on
                  ? AppColors.txRed.withValues(alpha: 0.18)
                  : AppColors.surface,
              border: Border.all(color: color, width: 2),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: AppColors.txRed.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.power_settings_new,
              color: color,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
