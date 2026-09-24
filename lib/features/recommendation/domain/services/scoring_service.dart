import 'dart:math' as math;

import '../models/place.dart';

/// S_i = w_D·S_dist + w_B·S_budget + w_C·S_comp + w_W·S_weather + w_P·S_pop + w_N·S_nov
/// (명세 3.2). Σw = 1.0
class ScoringWeights {
  const ScoringWeights({
    required this.distance,
    required this.budget,
    required this.companion,
    required this.weather,
    required this.popularity,
    required this.novelty,
  });

  final double distance;
  final double budget;
  final double companion;
  final double weather;
  final double popularity;
  final double novelty;

  double get sum => distance + budget + companion + weather + popularity + novelty;

  /// 기본 가중치 — 오늘의 베스트
  static const standard = ScoringWeights(
    distance: 0.25,
    budget: 0.20,
    companion: 0.20,
    weather: 0.15,
    popularity: 0.10,
    novelty: 0.10,
  );

  /// 색다른 선택 — Novelty 가중치 강화
  static const novel = ScoringWeights(
    distance: 0.18,
    budget: 0.12,
    companion: 0.15,
    weather: 0.10,
    popularity: 0.05,
    novelty: 0.40,
  );

  /// 가성비 — Budget 가중치 강화
  static const thrifty = ScoringWeights(
    distance: 0.20,
    budget: 0.45,
    companion: 0.12,
    weather: 0.10,
    popularity: 0.08,
    novelty: 0.05,
  );
}

class ScoringContext {
  const ScoringContext({
    required this.maxDistanceKm,
    required this.budgetPerSlot,
    required this.preferenceTags,
    required this.rainProbability,
  });

  /// d_max
  final double maxDistanceKm;

  /// B_slot — null이면 예산 제한 없음
  final int? budgetPerSlot;

  /// PreferenceTags(T) — 동행자 + 분위기 태그
  final Set<String> preferenceTags;

  /// P_rain (0~100)
  final int rainProbability;
}

class PlaceScore {
  const PlaceScore({
    required this.place,
    required this.distanceKm,
    required this.distance,
    required this.budget,
    required this.companion,
    required this.weather,
    required this.popularity,
    required this.novelty,
  });

  final Place place;
  final double distanceKm;
  final double distance;
  final double budget;
  final double companion;
  final double weather;
  final double popularity;
  final double novelty;

  double total(ScoringWeights w) =>
      w.distance * distance +
      w.budget * budget +
      w.companion * companion +
      w.weather * weather +
      w.popularity * popularity +
      w.novelty * novelty;
}

/// 개별 장소 Multi-Factor 점수 산출 (Pure function 모음)
class ScoringService {
  const ScoringService();

  /// S_dist = max(0, 1 − d_i / d_max)
  double distanceScore(double distanceKm, double maxKm) {
    if (maxKm <= 0) return 0;
    return math.max(0, 1 - distanceKm / maxKm);
  }

  /// S_budget = 1.0 (C ≤ B_slot) | max(0, 1 − (C − B_slot)/B_slot)
  double budgetScore(int cost, int? slot) {
    if (slot == null) return 1.0;
    if (cost <= slot) return 1.0;
    if (slot <= 0) return 0.0;
    return math.max(0, 1 - (cost - slot) / slot);
  }

  /// S_comp = |Tags ∩ PreferenceTags| / |PreferenceTags|
  double companionScore(Set<String> tags, Set<String> preference) {
    if (preference.isEmpty) return 0;
    return tags.intersection(preference).length / preference.length;
  }

  /// P_rain > 50% 이면 실내 1.0, 실외 0.3 (혼합은 중간값), 그 외 1.0
  double weatherScore(IndoorOutdoor type, int rainProbability) {
    if (rainProbability <= 50) return 1.0;
    return switch (type) {
      IndoorOutdoor.indoor => 1.0,
      IndoorOutdoor.outdoor => 0.3,
      IndoorOutdoor.mixed => 0.65,
    };
  }

  /// 명세에 정의되지 않은 S_pop: 평점 × 리뷰 수 신뢰도
  double popularityScore(double rating, int reviewCount) {
    // 평점 데이터가 없는 장소는 중립값
    if (rating <= 0 || reviewCount <= 0) return 0.5;
    final confidence = math.min(1.0, math.log(reviewCount + 1) / math.ln10 / 4);
    return (rating / 5).clamp(0, 1) * confidence;
  }

  /// S_nov = 1.0 (이벤트/팝업) | 1 / log10(ReviewCount + 10)
  double noveltyScore(bool isEvent, int reviewCount) {
    if (isEvent) return 1.0;
    // 리뷰 수를 모르는 장소는 중립값 (0이면 공식상 1.0이 되어 모두 '새로운 곳'이 되므로)
    if (reviewCount <= 0) return 0.5;
    return 1 / (math.log(reviewCount + 10) / math.ln10);
  }

  PlaceScore score(PlaceWithDistance candidate, ScoringContext ctx, {int? cost}) {
    final p = candidate.place;
    return PlaceScore(
      place: p,
      distanceKm: candidate.distanceKm,
      distance: distanceScore(candidate.distanceKm, ctx.maxDistanceKm),
      budget: budgetScore(cost ?? p.avgCost, ctx.budgetPerSlot),
      companion: companionScore(p.tags, ctx.preferenceTags),
      weather: weatherScore(p.indoorOutdoor, ctx.rainProbability),
      popularity: popularityScore(p.rating, p.reviewCount),
      novelty: noveltyScore(p.isEvent, p.reviewCount),
    );
  }
}
