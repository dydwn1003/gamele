import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/plan/domain/saved_plan.dart';
import '../features/recommendation/domain/models/course.dart';
import '../features/recommendation/domain/models/place.dart';
import '../features/situation/domain/situation.dart';

/// 이모지 대신 쓰는 아이콘 체계 — Material Symbols Rounded 한 가족으로 통일한다.
extension PlanTypeIcon on PlanType {
  IconData get icon => switch (this) {
    PlanType.best => Icons.local_fire_department_rounded,
    PlanType.novelty => Icons.auto_awesome_rounded,
    PlanType.cheap => Icons.savings_rounded,
  };
}

extension PlaceCategoryIcon on PlaceCategory {
  IconData get icon => switch (this) {
    PlaceCategory.park => Icons.park_rounded,
    PlaceCategory.exhibition => Icons.palette_rounded,
    PlaceCategory.popup => Icons.storefront_rounded,
    PlaceCategory.activity => Icons.sports_esports_rounded,
    PlaceCategory.food => Icons.restaurant_rounded,
    PlaceCategory.cafe => Icons.local_cafe_rounded,
    PlaceCategory.bar => Icons.wine_bar_rounded,
  };

  /// 카테고리 대표색 (커버 그라데이션의 진한 쪽)
  Color get tint => switch (this) {
    PlaceCategory.park => const Color(0xFF2FA86F),
    PlaceCategory.exhibition => const Color(0xFF7B61FF),
    PlaceCategory.popup => const Color(0xFFE85A8B),
    PlaceCategory.activity => const Color(0xFFFF8A3D),
    PlaceCategory.food => AppColors.primary,
    PlaceCategory.cafe => const Color(0xFFB0835C),
    PlaceCategory.bar => const Color(0xFF4A4AB5),
  };
}

extension CompanionIcon on Companion {
  IconData get icon => switch (this) {
    Companion.couple => Icons.favorite_rounded,
    Companion.friend => Icons.groups_rounded,
    Companion.solo => Icons.self_improvement_rounded,
    Companion.family => Icons.family_restroom_rounded,
  };
}

extension TimeBudgetIcon on TimeBudget {
  IconData get icon => switch (this) {
    TimeBudget.short => Icons.timer_rounded,
    TimeBudget.halfDay => Icons.wb_twilight_rounded,
    TimeBudget.fullDay => Icons.wb_sunny_rounded,
  };
}

extension MoodIcon on Mood {
  IconData get icon => switch (this) {
    Mood.healing => Icons.spa_rounded,
    Mood.insta => Icons.photo_camera_rounded,
    Mood.foodie => Icons.ramen_dining_rounded,
    Mood.active => Icons.directions_run_rounded,
  };
}

extension TravelRangeIcon on TravelRange {
  IconData get icon => switch (this) {
    TravelRange.walk15 => Icons.directions_walk_rounded,
    TravelRange.transit30 => Icons.directions_bus_rounded,
    TravelRange.hour => Icons.directions_subway_rounded,
  };
}

extension FeedbackRatingIcon on FeedbackRating {
  IconData get icon => switch (this) {
    FeedbackRating.like => Icons.sentiment_very_satisfied_rounded,
    FeedbackRating.neutral => Icons.sentiment_neutral_rounded,
    FeedbackRating.dislike => Icons.sentiment_dissatisfied_rounded,
  };
}

/// 둥근 사각 배경 위의 아이콘 (배지·목록 앞머리용)
class IconBubble extends StatelessWidget {
  const IconBubble(
    this.icon, {
    super.key,
    this.color = AppColors.primary,
    this.size = 36,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// true면 진한 배경 + 흰 아이콘
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.56, color: filled ? Colors.white : color),
    );
  }
}
