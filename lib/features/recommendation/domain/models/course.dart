import '../../../../core/utils/geo_utils.dart';
import '../../../situation/domain/situation.dart';
import 'place.dart';

/// 추천 결과 3종 (DB `plans.plan_type`)
enum PlanType {
  best('BEST', '오늘의 베스트', '🔥'),
  novelty('NOVELTY', '색다르게', '🎲'),
  cheap('CHEAP', '가성비', '💰');

  const PlanType(this.code, this.label, this.emoji);

  final String code;
  final String label;
  final String emoji;

  static PlanType fromCode(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => PlanType.best);
}

class CourseStop {
  const CourseStop({
    required this.place,
    required this.start,
    required this.end,
    required this.cost,
    required this.travel,
  });

  final Place place;
  final DateTime start;
  final DateTime end;

  /// 1인 예상 비용
  final int cost;

  /// 이전 장소로부터의 이동 (첫 장소는 zero)
  final TravelEstimate travel;

  int get stayMinutes => end.difference(start).inMinutes;

  CourseStop copyWith({Place? place, DateTime? start, DateTime? end, int? cost, TravelEstimate? travel}) =>
      CourseStop(
        place: place ?? this.place,
        start: start ?? this.start,
        end: end ?? this.end,
        cost: cost ?? this.cost,
        travel: travel ?? this.travel,
      );

  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'cost': cost,
    'travel_minutes': travel.minutes,
    'travel_meters': travel.distanceMeters,
    'travel_mode': travel.mode.name,
  };

  factory CourseStop.fromJson(Map<String, dynamic> json) => CourseStop(
    place: Place.fromJson((json['place'] as Map).cast<String, dynamic>()),
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    cost: json['cost'] as int,
    travel: TravelEstimate(
      minutes: json['travel_minutes'] as int,
      distanceMeters: json['travel_meters'] as int,
      mode: TravelMode.values.byName(json['travel_mode'] as String),
    ),
  );
}

class Course {
  const Course({
    required this.id,
    required this.type,
    required this.title,
    required this.stops,
    required this.areaName,
    required this.companion,
    required this.budget,
    required this.score,
    this.mood,
    this.aiSummary,
  });

  final String id;
  final PlanType type;
  final String title;
  final List<CourseStop> stops;
  final String areaName;
  final Companion companion;
  final Budget budget;
  final Mood? mood;
  final double score;
  final String? aiSummary;

  DateTime get startAt => stops.first.start;
  DateTime get endAt => stops.last.end;

  int get totalMinutes => endAt.difference(startAt).inMinutes;
  int get totalCost => stops.fold(0, (s, e) => s + e.cost);
  int get totalDistanceMeters => stops.fold(0, (s, e) => s + e.travel.distanceMeters);
  int get travelMinutes => stops.fold(0, (s, e) => s + e.travel.minutes);

  bool get usesTransit => stops.any((s) => s.travel.mode == TravelMode.transit);

  /// 체류시간 가중 실내 비율 (0~100)
  int get indoorPercent {
    final total = stops.fold<int>(0, (s, e) => s + e.stayMinutes);
    if (total == 0) return 0;
    final indoor = stops.fold<double>(0, (s, e) => s + e.stayMinutes * e.place.indoorOutdoor.indoorWeight);
    return (indoor / total * 100).round();
  }

  /// 코스 동일성 판단용 (장소 id 조합)
  String get signature => stops.map((s) => s.place.id).join('>');

  bool get allPlacesRemote => stops.every((s) => s.place.fromRemote);

  Course copyWith({
    String? id,
    PlanType? type,
    String? title,
    List<CourseStop>? stops,
    String? aiSummary,
    double? score,
  }) => Course(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    stops: stops ?? this.stops,
    areaName: areaName,
    companion: companion,
    budget: budget,
    mood: mood,
    score: score ?? this.score,
    aiSummary: aiSummary ?? this.aiSummary,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'title': title,
    'stops': stops.map((s) => s.toJson()).toList(),
    'area_name': areaName,
    'companion': companion.code,
    'budget': budget.name,
    'mood': mood?.name,
    'score': score,
    'ai_summary': aiSummary,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    type: PlanType.fromCode(json['type'] as String),
    title: json['title'] as String,
    stops: (json['stops'] as List)
        .map((e) => CourseStop.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    areaName: json['area_name'] as String,
    companion: Companion.fromCode(json['companion'] as String),
    budget: Budget.values.byName(json['budget'] as String),
    mood: json['mood'] == null ? null : Mood.values.byName(json['mood'] as String),
    score: (json['score'] as num).toDouble(),
    aiSummary: json['ai_summary'] as String?,
  );
}
