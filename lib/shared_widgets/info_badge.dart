import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

/// 코스 요약 배지 (⏱️ 총 4시간 30분)
class InfoBadge extends StatelessWidget {
  const InfoBadge({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    this.background = AppColors.surface,
    this.showEmoji = true,
  });

  final String emoji;
  final String label;
  final String value;
  final Color background;
  final bool showEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.mediumAll),
      child: Row(
        children: [
          if (showEmoji) ...[Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption.copyWith(fontSize: 11)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyBold.copyWith(fontSize: 14, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 작은 태그 칩 (예약 필요, 무료 등)
class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.color = AppColors.primary, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smallAll,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
