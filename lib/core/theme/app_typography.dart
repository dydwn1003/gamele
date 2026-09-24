import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 디자인 토큰 — Typography (명세 1.1)
///
/// 토스·당근 같은 요즘 앱에서 쓰는 Pretendard 한 가족으로 통일하고,
/// 큰 글자일수록 자간을 좁혀 단단하고 또렷한 인상을 준다.
abstract final class AppTypography {
  static const family = 'Pretendard';

  static const _base = TextStyle(
    fontFamily: family,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 히어로 헤드라인: 30 / 1.28 / 800
  static TextStyle get display =>
      _base.copyWith(fontSize: 30, height: 1.28, fontWeight: FontWeight.w800, letterSpacing: -1.2);

  /// 카드 제목 등 보조 헤드라인: 22 / 1.32 / 800
  static TextStyle get displaySmall =>
      _base.copyWith(fontSize: 22, height: 1.32, fontWeight: FontWeight.w800, letterSpacing: -0.8);

  /// Title Bold: 24 / 1.3 / 700
  static TextStyle get title =>
      _base.copyWith(fontSize: 24, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.8);

  /// Subtitle Bold: 18 / 1.4 / 700
  static TextStyle get subtitle =>
      _base.copyWith(fontSize: 18, height: 1.4, fontWeight: FontWeight.w700, letterSpacing: -0.5);

  /// Body Regular: 15 / 1.5 / 400
  static TextStyle get body =>
      _base.copyWith(fontSize: 15, height: 1.5, fontWeight: FontWeight.w400, letterSpacing: -0.3);

  static TextStyle get bodyBold => body.copyWith(fontWeight: FontWeight.w600);

  /// Caption: 12 / 1.4 / 500
  static TextStyle get caption => _base.copyWith(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: AppColors.textSecondary,
  );

  static TextTheme textTheme() => TextTheme(
    headlineMedium: display,
    titleLarge: title,
    titleMedium: subtitle,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: bodyBold,
  );
}
