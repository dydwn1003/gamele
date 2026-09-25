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

/// 장소별 아이콘: 세부 업종(네이버 분류)과 이름으로 고르고, 없으면 카테고리 아이콘.
extension PlaceIcon on Place {
  IconData get icon {
    final text = '${subcategory ?? ''} ${description ?? ''} $name';
    for (final (re, icon) in _placeIcons[category] ?? const <(RegExp, IconData)>[]) {
      if (re.hasMatch(text)) return icon;
    }
    return category.icon;
  }
}

/// 위에서부터 처음 맞는 규칙을 쓴다.
final _placeIcons = <PlaceCategory, List<(RegExp, IconData)>>{
  PlaceCategory.food: [
    (RegExp('브런치'), Icons.egg_alt_rounded),
    (RegExp('버거|햄버거|샌드위치'), Icons.lunch_dining_rounded),
    (RegExp('피자|파스타|이탈리아|양식|스테이크|프렌치|프랑스|스페인'), Icons.local_pizza_rounded),
    (RegExp('오마카세|스시|초밥|일식|해산물|횟집'), Icons.set_meal_rounded),
    (RegExp('라멘|국수|우동|칼국수|냉면|소바'), Icons.ramen_dining_rounded),
    (RegExp('고기|육류|삼겹|갈비|곱창|구이|닭'), Icons.outdoor_grill_rounded),
    (RegExp('시장|먹자골목|식당가'), Icons.storefront_rounded),
  ],
  PlaceCategory.cafe: [
    (RegExp('베이커리|제과|빵|베이글|도넛'), Icons.bakery_dining_rounded),
    (RegExp('아이스크림|빙수|젤라또'), Icons.icecream_rounded),
    (RegExp('디저트|케이크'), Icons.cake_rounded),
    (RegExp('전통차|찻집|티룸|다방'), Icons.emoji_food_beverage_rounded),
  ],
  PlaceCategory.bar: [
    (RegExp('와인'), Icons.wine_bar_rounded),
    (RegExp('호프|맥주|펍|비어'), Icons.sports_bar_rounded),
    (RegExp('이자카야|포장마차|포차|요리주점|막걸리|전통주'), Icons.liquor_rounded),
    (RegExp('LP|음악|재즈'), Icons.album_rounded),
    (RegExp(r'칵테일|위스키|바\(BAR\)|루프탑|바'), Icons.local_bar_rounded),
  ],
  PlaceCategory.activity: [
    (RegExp('방탈출'), Icons.key_rounded),
    (RegExp('보드게임|보드카페'), Icons.casino_rounded),
    (RegExp('만화'), Icons.auto_stories_rounded),
    (RegExp('노래'), Icons.mic_rounded),
    (RegExp('볼링'), Icons.sports_rounded),
    (RegExp('클라이밍|볼더링|트레킹'), Icons.hiking_rounded),
    (RegExp('셀프사진|포토|사진|스티커'), Icons.photo_camera_rounded),
    (RegExp('공방|공예|클래스|도자기|향수|캔들'), Icons.brush_rounded),
    (RegExp('공연|연극|뮤지컬'), Icons.theater_comedy_rounded),
    (RegExp('아쿠아리움'), Icons.scuba_diving_rounded),
    (RegExp('유람선|요트'), Icons.directions_boat_rounded),
    (RegExp('자전거'), Icons.pedal_bike_rounded),
    (RegExp('테마파크|놀이공원'), Icons.attractions_rounded),
    (RegExp('전망'), Icons.landscape_rounded),
    (RegExp('한복'), Icons.checkroom_rounded),
  ],
  PlaceCategory.exhibition: [
    (RegExp('박물관|기념관|문학관'), Icons.account_balance_rounded),
    (RegExp('고궁|궁|유산'), Icons.castle_rounded),
    (RegExp('생태|식물'), Icons.eco_rounded),
  ],
  PlaceCategory.park: [
    (RegExp('한강|하천|호수|계곡'), Icons.water_rounded),
    (RegExp('숲|둘레길|왕릉|등산|산림'), Icons.forest_rounded),
    (RegExp('정원|꽃|식물원'), Icons.local_florist_rounded),
    (RegExp('사찰'), Icons.temple_buddhist_rounded),
    (RegExp('전망|성곽'), Icons.landscape_rounded),
  ],
  PlaceCategory.popup: [
    (RegExp('서점|책|도서관'), Icons.menu_book_rounded),
    (RegExp('시장|마켓'), Icons.shopping_basket_rounded),
  ],
};

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
