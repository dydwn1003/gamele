import 'package:flutter/material.dart';

/// 디자인 토큰 — Color Palette (명세 1.1)
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFFFF5A5F); // Vibrant Coral
  static const primarySoft = Color(0xFFFFECEC);
  static const primaryDeep = Color(0xFFE8464B);
  static const secondary = Color(0xFF38B6FF); // Bright Sky
  static const secondarySoft = Color(0xFFE6F5FF);

  // Surface
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F8FA);
  static const border = Color(0xFFEEEEEE);
  static const disabled = Color(0xFFE0E0E0);

  // Text
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF767676);
  static const textMuted = Color(0xFF9E9E9E);

  // Status
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFFFAB00);
  static const error = Color(0xFFFF3D00);

  // 감성 그라데이션 (노을 → 복숭아 → 하늘)
  static const sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5A5F), Color(0xFFFF8A6B), Color(0xFFFFB38A)],
  );

  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF5A5F), Color(0xFFFF7A6E)],
  );

  static const aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5A5F), Color(0xFFB889FF), Color(0xFF38B6FF)],
  );
}
