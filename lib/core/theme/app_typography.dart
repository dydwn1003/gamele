import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 디자인 토큰 — Typography (명세 1.1)
///
/// 본문은 가독성 좋은 Noto Sans KR, 감성 헤드라인은 Gowun Batang(명조)을 섞어
/// "오늘의집 감성 카드" 같은 따뜻한 톤을 낸다.
abstract final class AppTypography {
  static TextStyle get _sans => GoogleFonts.notoSansKr(color: AppColors.textPrimary, letterSpacing: -0.3);

  static TextStyle get _serif =>
      GoogleFonts.gowunBatang(fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.4);

  /// Title Bold: 24 / 1.3 / 700
  static TextStyle get title => _sans.copyWith(fontSize: 24, height: 1.3, fontWeight: FontWeight.w700);

  /// Subtitle Bold: 18 / 1.4 / 700
  static TextStyle get subtitle => _sans.copyWith(fontSize: 18, height: 1.4, fontWeight: FontWeight.w700);

  /// Body Regular: 15 / 1.5 / 400
  static TextStyle get body => _sans.copyWith(fontSize: 15, height: 1.5, fontWeight: FontWeight.w400);

  static TextStyle get bodyBold => body.copyWith(fontWeight: FontWeight.w700);

  /// Caption: 12 / 1.4 / 400
  static TextStyle get caption =>
      _sans.copyWith(fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, color: AppColors.textSecondary);

  /// 감성 헤드라인 (명조)
  static TextStyle get display => _serif.copyWith(fontSize: 28, height: 1.35, fontWeight: FontWeight.w700);

  static TextStyle get displaySmall =>
      _serif.copyWith(fontSize: 20, height: 1.4, fontWeight: FontWeight.w700);

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
