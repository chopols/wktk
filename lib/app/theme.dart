/// 앱 테마: 레트로-모던 무전기 컨셉.
///
/// 다크(기본) + 라이트 테마를 모두 제공한다.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── 다크 바디 톤 ──
  static const Color body = Color(0xFF1A1D21); // 무광 블랙
  static const Color bodyDeep = Color(0xFF101214);
  static const Color surface = Color(0xFF24282E);
  static const Color surfaceHigh = Color(0xFF2E343C);

  // ── 포인트 컬러 (앰버) ──
  static const Color accent = Color(0xFFFF9A21);
  static const Color accentDim = Color(0xFFC97700);
  static const Color accentSoft = Color(0xFF3A2D18);

  // ── 상태 LED ──
  static const Color txRed = Color(0xFFFF4A3D);
  static const Color rxGreen = Color(0xFF31D971);
  static const Color idleGreenDim = Color(0xFF2E5C42);

  // ── LCD ──
  static const Color lcdBg = Color(0xFF202B25);
  static const Color lcdGrid = Color(0x149FE8B0);
  static const Color lcdText = Color(0xFFB8F2C1);
  static const Color lcdTextDim = Color(0xFF4E7A63);

  // ── 텍스트 ──
  static const Color textHi = Color(0xFFE9ECF0);
  static const Color textMid = Color(0xFF9AA3AD);
  static const Color textLow = Color(0xFF575F68);

  // ── 라이트 테마 ──
  static const Color bodyLight = Color(0xFFE7EAEE);
  static const Color bodyLightDeep = Color(0xFFD5DAE1);
  static const Color surfaceLight = Color(0xFFF4F6F8);
  static const Color surfaceLightHigh = Color(0xFFFFFFFF);
  static const Color textHiLight = Color(0xFF1B1E22);
  static const Color textMidLight = Color(0xFF5A6470);
  static const Color textLowLight = Color(0xFF8A939E);
}

/// 무전기 하드웨어적인 무광/금속 느낌의 다크 다크테마.
ThemeData buildAppTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final scheme = isDark
      ? const ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: Color(0xFF1B1205),
          secondary: AppColors.accentDim,
          surface: AppColors.surface,
          error: AppColors.txRed,
        )
      : const ColorScheme.light(
          primary: AppColors.accentDim,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          surface: AppColors.surfaceLight,
          error: AppColors.txRed,
        );

  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppColors.body : AppColors.bodyLight,
    useMaterial3: true,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: isDark ? AppColors.textHi : AppColors.textHiLight,
    displayColor: isDark ? AppColors.textHi : AppColors.textHiLight,
  );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: isDark ? AppColors.surfaceHigh : AppColors.surfaceLightHigh,
    iconTheme: IconThemeData(
      color: isDark ? AppColors.textMid : AppColors.textMidLight,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.bodyDeep : AppColors.bodyLightDeep,
      foregroundColor: isDark ? AppColors.textHi : AppColors.textHiLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark
          ? AppColors.surfaceHigh
          : AppColors.surfaceLightHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? AppColors.textHi : AppColors.textHiLight,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
