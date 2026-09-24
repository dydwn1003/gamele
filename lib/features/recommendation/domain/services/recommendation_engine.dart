import 'package:uuid/uuid.dart';

import '../../../situation/domain/situation.dart';
import '../models/course.dart';
import '../models/place.dart';
import 'course_copywriter.dart';
import 'route_combinator.dart';
import 'scoring_service.dart';

class EngineRequest {
  const EngineRequest({
    required this.situation,
    required this.candidates,
    required this.areaName,
    required this.startAt,
    required this.maxDistanceKm,
    this.rainProbability = 0,
    this.excludedSignatures = const {},
  });

  final Situation situation;
  final List<PlaceWithDistance> candidates;
  final String areaName;
  final DateTime startAt;
  final double maxDistanceKm;
  final int rainProbability;
  final Set<String> excludedSignatures;
}

/// 결정형 추천 엔진 — AI 없이 Pure Algorithm으로 Top 3 코스를 만든다.
///
/// Step 1 Hard Filter → Step 2 Scoring → Step 3 Route Combinator
class RecommendationEngine {
  const RecommendationEngine({
    this.scoring = const ScoringService(),
    this.combinator = const RouteCombinator(),
  });

  final ScoringService scoring;
  final RouteCombinator combinator;

  static const _uuid = Uuid();

  /// 1인 비용 추정. 0원 예산이면 무료 입장 기준(price_min)으로 계산.
  int costOf(Place p, Budget budget) => budget == Budget.free ? p.priceMin : p.avgCost;

  /// Step 1: Hard Filter — 영업 여부, 예산 초과, 동행자 제약 (거리는 Repository에서)
  List<PlaceWithDistance> hardFilter(EngineRequest req) {
    final s = req.situation;
    final budget = s.budget!;
    final limit = s.time!.minutes;
    return req.candidates.where((c) {
      final p = c.place;
      if (c.distanceKm > req.maxDistanceKm) return false;
      // 예산: 가장 싼 가격도 1인 총예산을 넘으면 제외
      if (budget == Budget.free && p.priceMin > 0) return false;
      if (budget.won != null && p.priceMin > budget.won!) return false;
      // 동행자 제약: 가족 코스에는 바/심야 장소 제외
      if (s.companion == Companion.family && (p.category == PlaceCategory.bar || p.tags.contains('NIGHT'))) {
        return false;
      }
      // 영업: 코스 시간대 중 한 번이라도 체류 가능해야 함
      for (var offset = 0; offset < limit; offset += 30) {
        final start = req.startAt.add(Duration(minutes: offset));
        final end = start.add(Duration(minutes: (p.durationMinutes * RouteCombinator.minStayRatio).round()));
        if (p.isOpenDuring(start, end)) return true;
      }
      return false;
    }).toList();
  }

  Map<PlanType, Course> recommend(EngineRequest req) {
    final s = req.situation;
    assert(s.isComplete, 'Situation must be complete');
    final budget = s.budget!;
    final time = s.time!;
    final filtered = hardFilter(req);
    if (filtered.isEmpty) return const {};

    final ctx = ScoringContext(
      maxDistanceKm: req.maxDistanceKm,
      budgetPerSlot: budget.won == null ? null : (budget.won! / time.stopCount).round(),
      preferenceTags: {...s.companion!.preferenceTags, ...s.mood!.tags},
      rainProbability: req.rainProbability,
    );

    // Step 2: 개별 장소 점수
    final scores = [for (final c in filtered) scoring.score(c, ctx, cost: costOf(c.place, budget))];

    CombinatorInput input(ScoringWeights w, {Set<String> avoid = const {}, Set<String> exclude = const {}}) =>
        CombinatorInput(
          scores: scores,
          weights: w,
          startAt: req.startAt,
          timeLimitMinutes: time.minutes,
          stopCount: time.stopCount,
          costOf: (p) => costOf(p, budget),
          totalBudget: budget.won,
          leadCategories: s.mood!.leadCategories,
          excludedSignatures: {...req.excludedSignatures, ...exclude},
          avoidPlaceIds: avoid,
        );

    // 장소 수가 부족하면 한 단계 짧은 코스로 재시도
    var stopCount = time.stopCount;
    CombinedRoute? best;
    while (stopCount >= 2) {
      best = combinator.best(input(ScoringWeights.standard).withStops(stopCount));
      if (best != null) break;
      stopCount--;
    }
    if (best == null) return const {};

    final used = best.stops.map((e) => e.place.id).toSet();
    final novel = combinator.best(
      input(ScoringWeights.novel, avoid: used, exclude: {best.signature}).withStops(stopCount),
    );
    final used2 = {...used, ...?novel?.stops.map((e) => e.place.id)};
    final cheap = _cheapest(
      combinator.rank(
        input(
          ScoringWeights.thrifty,
          avoid: used2,
          exclude: {best.signature, if (novel != null) novel.signature},
        ).withStops(stopCount),
      ),
    );

    Course toCourse(CombinedRoute r, PlanType type) => Course(
      id: _uuid.v4(),
      type: type,
      title: CourseCopywriter.title(
        areaName: req.areaName,
        companion: s.companion!,
        mood: s.mood,
        type: type,
      ),
      stops: [
        for (final st in r.stops)
          CourseStop(place: st.place, start: st.start, end: st.end, cost: st.cost, travel: st.travel),
      ],
      areaName: req.areaName,
      companion: s.companion!,
      budget: budget,
      mood: s.mood,
      score: r.score,
    );

    return {
      PlanType.best: toCourse(best, PlanType.best),
      PlanType.novelty: toCourse(novel ?? best, PlanType.novelty),
      PlanType.cheap: toCourse(cheap ?? best, PlanType.cheap),
    };
  }

  /// 가성비: 상위 점수 코스 중 비용이 가장 낮은 코스 (동률이면 점수 순)
  CombinedRoute? _cheapest(List<CombinedRoute> ranked) {
    if (ranked.isEmpty) return null;
    final top = ranked.take(8).toList();
    int cost(CombinedRoute r) => r.stops.fold(0, (s, e) => s + e.cost);
    top.sort((a, b) {
      final c = cost(a).compareTo(cost(b));
      return c != 0 ? c : b.score.compareTo(a.score);
    });
    return top.first;
  }
}

extension on CombinatorInput {
  CombinatorInput withStops(int stops) => CombinatorInput(
    scores: scores,
    weights: weights,
    startAt: startAt,
    timeLimitMinutes: timeLimitMinutes,
    stopCount: stops,
    costOf: costOf,
    totalBudget: totalBudget,
    leadCategories: leadCategories,
    excludedSignatures: excludedSignatures,
    avoidPlaceIds: avoidPlaceIds,
  );
}
