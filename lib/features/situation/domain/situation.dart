import 'package:latlong2/latlong.dart';

/// Q1. 누구와 — DB `companion_type` enum과 1:1
enum Companion {
  couple('COUPLE', '연인', '💑', '둘만의 설렘'),
  friend('FRIEND', '친구', '👯', '왁자지껄 수다'),
  solo('SOLO', '혼자', '🧘', '온전한 나의 시간'),
  family('FAMILY', '가족', '👨‍👩‍👧', '함께라서 좋은 날');

  const Companion(this.code, this.label, this.emoji, this.tagline);

  final String code;
  final String label;
  final String emoji;
  final String tagline;

  /// S_comp 계산용 PreferenceTags(T) (명세 3.2)
  Set<String> get preferenceTags => switch (this) {
    Companion.couple => {'ROMANTIC', 'DATE', 'INSTAGRAM', 'VIEW'},
    Companion.friend => {'GROUP', 'FUN', 'TRENDY', 'ACTIVE'},
    Companion.solo => {'SOLO_FRIENDLY', 'QUIET', 'ART'},
    Companion.family => {'KIDS', 'SPACIOUS', 'HEALING'},
  };

  static Companion fromCode(String code) =>
      values.firstWhere((c) => c.code == code, orElse: () => Companion.couple);
}

/// Q2. 시간
enum TimeBudget {
  short('지금 1~2시간', '⏱️', 120),
  halfDay('반나절', '🌤️', 300, sub: '4~5시간'),
  fullDay('하루종일', '🌈', 480, sub: '8시간+');

  const TimeBudget(this.label, this.emoji, this.minutes, {this.sub = ''});

  final String label;
  final String emoji;
  final int minutes;
  final String sub;

  /// 코스에 담을 장소 개수
  int get stopCount => switch (this) {
    TimeBudget.short => 2,
    TimeBudget.halfDay => 3,
    TimeBudget.fullDay => 4,
  };
}

/// Q3. 예산 (1인 기준)
enum Budget {
  free('0원', 0),
  w30k('3만원', 30000),
  w50k('5만원', 50000),
  w100k('10만원+', 100000),
  any('상관없음', null);

  const Budget(this.label, this.won);

  final String label;

  /// null = 제한 없음
  final int? won;

  /// DB `total_budget` 저장용 (상관없음은 0으로 기록)
  int get storedValue => won ?? 0;
}

/// Q4. 분위기/목적
enum Mood {
  healing('힐링/조용', '🌿', {'QUIET', 'HEALING', 'NATURE'}),
  insta('인스타/전시', '📸', {'INSTAGRAM', 'ART', 'TRENDY'}),
  foodie('맛있는 음식', '🍜', {'FOODIE', 'LOCAL'}),
  active('활동적/체험', '🔥', {'ACTIVE', 'FUN'});

  const Mood(this.label, this.emoji, this.tags);

  final String label;
  final String emoji;
  final Set<String> tags;

  /// 코스 첫 장소로 선호하는 카테고리
  Set<String> get leadCategories => switch (this) {
    Mood.healing => {'PARK'},
    Mood.insta => {'EXHIBITION', 'POPUP'},
    Mood.foodie => {'FOOD'},
    Mood.active => {'ACTIVITY'},
  };
}

/// Q5. 이동 범주
enum TravelRange {
  walk15('도보 15분', '🚶', 1.2),
  transit30('대중교통 30분', '🚌', 5.0),
  hour('1시간 이내', '🚇', 12.0);

  const TravelRange(this.label, this.emoji, this.radiusKm);

  final String label;
  final String emoji;

  /// 현재 위치 기준 탐색 반경 (d_max)
  final double radiusKm;
}

enum LocationSource { gps, manual, fallback }

class UserLocation {
  const UserLocation({required this.point, required this.areaName, required this.source});

  final LatLng point;
  final String areaName;
  final LocationSource source;
}

/// 사용자 상황 입력 전체 상태
class Situation {
  const Situation({
    this.companion,
    this.time,
    this.budget,
    this.mood,
    this.range,
    this.location,
    this.departAt,
  });

  final Companion? companion;
  final TimeBudget? time;
  final Budget? budget;
  final Mood? mood;
  final TravelRange? range;
  final UserLocation? location;

  /// 출발 시각. null이면 '지금 출발'
  final DateTime? departAt;

  static const totalSteps = 5;

  int get answeredCount => [companion, time, budget, mood, range].where((v) => v != null).length;

  bool get isComplete => answeredCount == totalSteps;

  /// 아직 답하지 않은 첫 질문 번호 (0-base). 모두 답했으면 null.
  int? get firstMissingStep {
    final answers = [companion, time, budget, mood, range];
    final i = answers.indexWhere((v) => v == null);
    return i < 0 ? null : i;
  }

  Situation copyWith({
    Companion? companion,
    TimeBudget? time,
    Budget? budget,
    Mood? mood,
    TravelRange? range,
    UserLocation? location,
    DateTime? departAt,
    bool departNow = false,
  }) => Situation(
    companion: companion ?? this.companion,
    time: time ?? this.time,
    budget: budget ?? this.budget,
    mood: mood ?? this.mood,
    range: range ?? this.range,
    location: location ?? this.location,
    departAt: departNow ? null : (departAt ?? this.departAt),
  );
}
