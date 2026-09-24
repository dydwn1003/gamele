import '../../../../core/constants/areas.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../situation/domain/situation.dart';
import '../models/course.dart';
import '../models/place.dart';

/// 코스 제목/로컬 총평 생성기 — 데이터에 있는 사실만 조합한다.
abstract final class CourseCopywriter {
  static String title({
    required String areaName,
    required Companion companion,
    required Mood? mood,
    required PlanType type,
  }) {
    final area = Areas.shortName(areaName);
    final vibe = switch (type) {
      PlanType.novelty => '색다른',
      PlanType.cheap => '알뜰',
      PlanType.best => switch (mood) {
        Mood.healing => '힐링',
        Mood.insta => '감성',
        Mood.foodie => '미식',
        Mood.active => '액티브',
        null => '오늘의',
      },
    };
    final who = switch (companion) {
      Companion.couple => '데이트',
      Companion.friend => '우정',
      Companion.solo => '나홀로',
      Companion.family => '가족 나들이',
    };
    return '$area $vibe $who 코스';
  }

  static String _verb(PlaceCategory c) => switch (c) {
    PlaceCategory.park => '천천히 걸으며',
    PlaceCategory.exhibition => '작품에 빠져들며',
    PlaceCategory.popup => '요즘 감성을 구경하며',
    PlaceCategory.activity => '신나게 몸을 움직이며',
    PlaceCategory.food => '든든하게 배를 채우며',
    PlaceCategory.cafe => '달콤한 한 잔으로',
    PlaceCategory.bar => '분위기 있는 한 잔으로',
  };

  static String _ending(PlaceCategory c) => switch (c) {
    PlaceCategory.park => '여유로운 산책으로',
    PlaceCategory.exhibition => '전시 한 편으로',
    PlaceCategory.popup => '구경하는 재미로',
    PlaceCategory.activity => '신나는 체험으로',
    PlaceCategory.food => '맛있는 한 끼로',
    PlaceCategory.cafe => '달콤한 한 잔으로',
    PlaceCategory.bar => '분위기 있는 한 잔으로',
  };

  /// AI 호출이 불가할 때 쓰는 2문장 총평 (Zero-Hallucination: 코스 데이터만 사용)
  static String localSummary(Course course) {
    final first = course.stops.first.place;
    final last = course.stops.last.place;
    final firstName = first.name;
    final lastName = last.name;
    final s1 =
        '$firstName에서 ${_verb(first.category)} 시작해 $lastName의 ${_ending(last.category)} 마무리하는 ${Fmt.duration(course.totalMinutes)} 코스예요.';
    final move = course.usesTransit
        ? '대중교통을 포함해 이동 ${Fmt.duration(course.travelMinutes)}'
        : '걸어서 ${Fmt.duration(course.travelMinutes)}';
    final s2 = course.totalCost == 0
        ? '$move이면 충분하고, 비용 걱정 없이 무료로 즐길 수 있어요.'
        : '$move이면 충분하고, 1인 ${Fmt.won(course.totalCost)}으로 알차게 즐길 수 있어요.';
    return '$s1 $s2';
  }

  static String travelLabel(TravelEstimate t) => t.mode == TravelMode.walk
      ? '도보 ${t.minutes}분 · ${Fmt.distance(t.distanceMeters)}'
      : '대중교통 약 ${t.minutes}분 · ${Fmt.distance(t.distanceMeters)}';
}
