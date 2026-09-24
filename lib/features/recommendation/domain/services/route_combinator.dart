import 'dart:math' as math;

import '../../../../core/utils/geo_utils.dart';
import '../models/place.dart';
import 'scoring_service.dart';

typedef Slot = Set<PlaceCategory>;

const _attraction = {PlaceCategory.park, PlaceCategory.exhibition, PlaceCategory.popup};

/// 카테고리 플로우 규칙 (명세 3.3)
///  - PARK / EXHIBITION / POPUP → FOOD → CAFE
///  - ACTIVITY → FOOD → CAFE / BAR
/// 시간이 짧으면 2곳, 하루종일이면 4곳 코스로 확장한다.
abstract final class CategoryFlow {
  static List<List<Slot>> patterns(int stopCount) => switch (stopCount) {
    <= 2 => [
      [
        {..._attraction, PlaceCategory.activity},
        {PlaceCategory.cafe},
      ],
      [
        {..._attraction, PlaceCategory.activity},
        {PlaceCategory.food},
      ],
      [
        {PlaceCategory.food},
        {PlaceCategory.cafe},
      ],
      [
        {PlaceCategory.food},
        {PlaceCategory.bar},
      ],
    ],
    3 => [
      [
        _attraction,
        {PlaceCategory.food},
        {PlaceCategory.cafe},
      ],
      [
        {PlaceCategory.activity},
        {PlaceCategory.food},
        {PlaceCategory.cafe, PlaceCategory.bar},
      ],
    ],
    _ => [
      [
        _attraction,
        {PlaceCategory.food},
        {..._attraction, PlaceCategory.activity},
        {PlaceCategory.cafe, PlaceCategory.bar},
      ],
      [
        {PlaceCategory.activity},
        {PlaceCategory.food},
        _attraction,
        {PlaceCategory.cafe, PlaceCategory.bar},
      ],
    ],
  };
}

class CombinatorInput {
  const CombinatorInput({
    required this.scores,
    required this.weights,
    required this.startAt,
    required this.timeLimitMinutes,
    required this.stopCount,
    required this.costOf,
    this.totalBudget,
    this.leadCategories = const {},
    this.excludedSignatures = const {},
    this.avoidPlaceIds = const {},
  });

  final List<PlaceScore> scores;
  final ScoringWeights weights;
  final DateTime startAt;

  /// T_user
  final int timeLimitMinutes;
  final int stopCount;
  final int Function(Place) costOf;

  /// 1인 총 예산 (null = 제한 없음)
  final int? totalBudget;

  /// 분위기에 맞는 첫 장소 카테고리 (가산점)
  final Set<String> leadCategories;

  /// 이미 보여준 코스 조합 (다시 생성 시 제외)
  final Set<String> excludedSignatures;

  /// 다른 탭 코스와 겹치지 않게 감점할 장소
  final Set<String> avoidPlaceIds;
}

class PlannedStop {
  const PlannedStop({
    required this.place,
    required this.start,
    required this.end,
    required this.cost,
    required this.travel,
  });

  final Place place;
  final DateTime start;
  final DateTime end;
  final int cost;
  final TravelEstimate travel;
}

class CombinedRoute {
  const CombinedRoute(this.stops, this.score);

  final List<PlannedStop> stops;
  final double score;

  String get signature => stops.map((s) => s.place.id).join('>');
}

/// Route Combinator & Optimizer (명세 3.3)
///
/// 카테고리 패턴별로 상위 K개 후보를 DFS로 조합하며,
///   Σ Duration + Σ TravelTime ≤ T_user, Σ Cost ≤ Budget, 방문 시각 영업 여부
/// 를 모두 만족하는 코스 중 최고 점수 조합을 반환한다.
class RouteCombinator {
  const RouteCombinator();

  /// 체류시간은 원래의 75%까지 줄여서 시간 안에 맞출 수 있다.
  static const minStayRatio = 0.75;

  CombinedRoute? best(CombinatorInput input) {
    final ranked = rank(input);
    return ranked.isEmpty ? null : ranked.first;
  }

  List<CombinedRoute> rank(CombinatorInput input, {int limit = 20}) {
    final results = <CombinedRoute>[];
    final seen = <String>{};
    final k = switch (input.stopCount) {
      <= 2 => 12,
      3 => 9,
      _ => 7,
    };

    for (final pattern in CategoryFlow.patterns(input.stopCount)) {
      final slots = [
        for (final slot in pattern)
          (input.scores.where((s) => slot.contains(s.place.category)).toList()
                ..sort((a, b) => _placeValue(b, input).compareTo(_placeValue(a, input))))
              .take(k)
              .toList(),
      ];
      if (slots.any((s) => s.isEmpty)) continue;
      _dfs(input, slots, 0, <PlaceScore>[], results, seen);
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  double _placeValue(PlaceScore s, CombinatorInput input) {
    var v = s.total(input.weights);
    if (input.avoidPlaceIds.contains(s.place.id)) v -= 0.12;
    // 검증된 인기 가게는 코스 조합에서도 우선한다
    if (s.place.isPopular) v += 0.08;
    return v;
  }

  void _dfs(
    CombinatorInput input,
    List<List<PlaceScore>> slots,
    int depth,
    List<PlaceScore> chosen,
    List<CombinedRoute> out,
    Set<String> seen,
  ) {
    if (depth == slots.length) {
      final route = _build(input, chosen);
      if (route != null && seen.add(route.signature)) out.add(route);
      return;
    }
    for (final candidate in slots[depth]) {
      if (chosen.any((c) => c.place.id == candidate.place.id)) continue;
      chosen.add(candidate);
      if (_feasiblePrefix(input, chosen)) {
        _dfs(input, slots, depth + 1, chosen, out, seen);
      }
      chosen.removeLast();
    }
  }

  /// 가지치기: 최소 체류시간으로도 시간/예산 초과면 중단
  bool _feasiblePrefix(CombinatorInput input, List<PlaceScore> chosen) {
    var minutes = 0.0;
    var cost = 0;
    for (var i = 0; i < chosen.length; i++) {
      final p = chosen[i].place;
      if (i > 0) minutes += GeoUtils.estimate(chosen[i - 1].place.point, p.point).minutes;
      minutes += p.durationMinutes * minStayRatio;
      cost += input.costOf(p);
    }
    if (minutes > input.timeLimitMinutes) return false;
    if (input.totalBudget != null && cost > input.totalBudget!) return false;
    return true;
  }

  CombinedRoute? _build(CombinatorInput input, List<PlaceScore> chosen) {
    final travels = <TravelEstimate>[TravelEstimate.zero];
    for (var i = 1; i < chosen.length; i++) {
      travels.add(GeoUtils.estimate(chosen[i - 1].place.point, chosen[i].place.point));
    }
    final travelTotal = travels.fold<int>(0, (s, t) => s + t.minutes);
    final stayTotal = chosen.fold<int>(0, (s, c) => s + c.place.durationMinutes);

    // Total Time = Σ Duration + Σ TravelTime ≤ T_user
    final available = input.timeLimitMinutes - travelTotal;
    final ratio = math.min(1.0, available / stayTotal);
    if (ratio < minStayRatio) return null;

    var clock = input.startAt;
    final stops = <PlannedStop>[];
    var cost = 0;
    for (var i = 0; i < chosen.length; i++) {
      final place = chosen[i].place;
      clock = clock.add(Duration(minutes: travels[i].minutes));
      final stay = _roundTo5(place.durationMinutes * ratio);
      final end = clock.add(Duration(minutes: stay));
      if (!place.isOpenDuring(clock, end)) return null;
      final c = input.costOf(place);
      cost += c;
      stops.add(PlannedStop(place: place, start: clock, end: end, cost: c, travel: travels[i]));
      clock = end;
    }
    if (input.totalBudget != null && cost > input.totalBudget!) return null;

    final signature = stops.map((s) => s.place.id).join('>');
    if (input.excludedSignatures.contains(signature)) return null;

    return CombinedRoute(stops, _routeScore(input, chosen, travelTotal, clock));
  }

  double _routeScore(CombinatorInput input, List<PlaceScore> chosen, int travelMinutes, DateTime endAt) {
    final mean = chosen.fold<double>(0, (s, c) => s + _placeValue(c, input)) / chosen.length;
    final lead = input.leadCategories.contains(chosen.first.place.category.code) ? 0.08 : 0;
    // 이동이 길수록 감점
    final travelPenalty = travelMinutes / input.timeLimitMinutes * 0.5;
    // 주어진 시간을 너무 적게 쓰면 감점
    final used = endAt.difference(input.startAt).inMinutes / input.timeLimitMinutes;
    final underfill = used < 0.5 ? (0.5 - used) * 0.3 : 0;
    // 실내/실외가 섞이면 소폭 가산 (코스 리듬감)
    final mixed = chosen.map((c) => c.place.indoorOutdoor).toSet().length > 1 ? 0.02 : 0;
    return mean + lead - travelPenalty - underfill + mixed;
  }

  static int _roundTo5(double minutes) => math.max(20, (minutes / 5).round() * 5);
}
