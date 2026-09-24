// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwohaji/core/constants/areas.dart';
import 'package:mwohaji/core/utils/geo_utils.dart';
import 'package:mwohaji/features/recommendation/domain/models/course.dart';
import 'package:mwohaji/features/recommendation/domain/models/place.dart';
import 'package:mwohaji/features/recommendation/domain/services/course_copywriter.dart';
import 'package:mwohaji/features/recommendation/domain/services/recommendation_engine.dart';
import 'package:mwohaji/features/recommendation/domain/services/scoring_service.dart';
import 'package:mwohaji/features/situation/domain/situation.dart';

List<PlaceWithDistance> _mockCandidates(double radiusKm) {
  final raw = jsonDecode(File('assets/mock/places.json').readAsStringSync()) as List;
  final anchor = Areas.seongsu.center;
  return [
    for (final j in raw.cast<Map<String, dynamic>>())
      if (GeoUtils.distanceKm(anchor, Place.fromJson(j).point) <= radiusKm)
        PlaceWithDistance(Place.fromJson(j), GeoUtils.distanceKm(anchor, Place.fromJson(j).point)),
  ];
}

Situation _situation({
  TimeBudget time = TimeBudget.halfDay,
  Budget budget = Budget.w50k,
  Companion companion = Companion.couple,
  Mood mood = Mood.insta,
  TravelRange range = TravelRange.transit30,
}) => Situation(
  companion: companion,
  time: time,
  budget: budget,
  mood: mood,
  range: range,
  location: UserLocation(
    point: Areas.seongsu.center,
    areaName: Areas.seongsu.name,
    source: LocationSource.manual,
  ),
);

Map<PlanType, Course> _run(Situation s, {DateTime? start}) => const RecommendationEngine().recommend(
  EngineRequest(
    situation: s,
    candidates: _mockCandidates(s.range!.radiusKm),
    areaName: Areas.seongsu.name,
    startAt: start ?? DateTime(2026, 9, 26, 14, 30), // 토요일 오후
    maxDistanceKm: s.range!.radiusKm,
  ),
);

void main() {
  group('ScoringService (명세 3.2)', () {
    const s = ScoringService();

    test('distance score', () {
      expect(s.distanceScore(0, 5), 1);
      expect(s.distanceScore(2.5, 5), 0.5);
      expect(s.distanceScore(7, 5), 0);
    });

    test('budget score', () {
      expect(s.budgetScore(10000, 20000), 1);
      expect(s.budgetScore(30000, 20000), 0.5);
      expect(s.budgetScore(50000, 20000), 0);
      expect(s.budgetScore(50000, null), 1);
    });

    test('weather score', () {
      expect(s.weatherScore(IndoorOutdoor.outdoor, 80), 0.3);
      expect(s.weatherScore(IndoorOutdoor.indoor, 80), 1);
      expect(s.weatherScore(IndoorOutdoor.outdoor, 10), 1);
    });

    test('novelty score', () {
      expect(s.noveltyScore(true, 99999), 1);
      expect(s.noveltyScore(false, 0), 0.5); // 리뷰 수 미상
      expect(s.noveltyScore(false, 90), closeTo(0.5, 1e-9));
      expect(s.noveltyScore(false, 990), closeTo(1 / 3, 1e-9));
    });

    test('weights sum to 1', () {
      for (final w in [ScoringWeights.standard, ScoringWeights.novel, ScoringWeights.thrifty]) {
        expect(w.sum, closeTo(1, 1e-9));
      }
    });
  });

  group('RecommendationEngine', () {
    test('half day → 3 distinct plans honoring time & budget', () {
      final s = _situation();
      final result = _run(s);
      expect(result.keys, containsAll(PlanType.values));
      for (final c in result.values) {
        expect(c.stops.length, 3);
        expect(c.totalMinutes, lessThanOrEqualTo(s.time!.minutes));
        expect(c.totalCost, lessThanOrEqualTo(50000));
        expect(c.stops[1].place.category, PlaceCategory.food);
      }
      expect(result[PlanType.best]!.signature, isNot(result[PlanType.novelty]!.signature));
      expect(result[PlanType.cheap]!.totalCost, lessThanOrEqualTo(result[PlanType.best]!.totalCost));

      for (final c in result.values) {
        print(
          '${c.type.label}: ${c.title} | ${c.stops.map((e) => e.place.name).join(' → ')} '
          '| ${c.totalMinutes}분 ${c.totalCost}원\n  ${CourseCopywriter.localSummary(c)}',
        );
      }
    });

    test('short time → 2 stops', () {
      final result = _run(_situation(time: TimeBudget.short, range: TravelRange.walk15));
      expect(result, isNotEmpty);
      expect(result[PlanType.best]!.stops.length, 2);
      expect(result[PlanType.best]!.totalMinutes, lessThanOrEqualTo(120));
    });

    test('full day → 4 stops', () {
      final result = _run(
        _situation(time: TimeBudget.fullDay, budget: Budget.any),
        start: DateTime(2026, 9, 26, 11),
      );
      expect(result[PlanType.best]!.stops.length, 4);
    });

    test('free budget → only free places', () {
      final result = _run(_situation(budget: Budget.free, mood: Mood.healing));
      for (final c in result.values) {
        expect(c.totalCost, 0);
      }
    });

    test('family excludes bars', () {
      final result = _run(
        _situation(companion: Companion.family, time: TimeBudget.fullDay, budget: Budget.any),
        start: DateTime(2026, 9, 26, 11),
      );
      for (final c in result.values) {
        expect(c.stops.any((s) => s.place.category == PlaceCategory.bar), isFalse);
      }
    });

    test('regenerate excludes shown signatures', () {
      final s = _situation();
      final first = _run(s);
      final second = const RecommendationEngine().recommend(
        EngineRequest(
          situation: s,
          candidates: _mockCandidates(5),
          areaName: '서울 성수',
          startAt: DateTime(2026, 9, 26, 14, 30),
          maxDistanceKm: 5,
          excludedSignatures: first.values.map((c) => c.signature).toSet(),
        ),
      );
      expect(second, isNotEmpty);
      final shown = first.values.map((c) => c.signature).toSet();
      expect(second.values.where((c) => shown.contains(c.signature)), isEmpty);
    });

    test('every area has enough data for a course', () {
      final raw = jsonDecode(File('assets/mock/places.json').readAsStringSync()) as List;
      final places = raw.cast<Map<String, dynamic>>().map(Place.fromJson).toList();
      for (final area in Areas.all) {
        for (final time in TimeBudget.values) {
          final s = _situation(time: time, budget: Budget.any, range: TravelRange.transit30);
          final result = const RecommendationEngine().recommend(
            EngineRequest(
              situation: s,
              candidates: [
                for (final p in places)
                  if (GeoUtils.distanceKm(area.center, p.point) <= 5)
                    PlaceWithDistance(p, GeoUtils.distanceKm(area.center, p.point)),
              ],
              areaName: area.name,
              startAt: DateTime(2026, 9, 26, 13),
              maxDistanceKm: 5,
            ),
          );
          expect(result, isNotEmpty, reason: '${area.name} / ${time.label}');
          print(
            '${area.name} ${time.label}: ${result[PlanType.best]!.stops.map((e) => e.place.name).join(' → ')}',
          );
        }
      }
    });

    test('popular places are preferred', () {
      final s = _situation();
      final base = _mockCandidates(5);
      final plain = _run(s)[PlanType.best]!;
      final foodIds = base
          .where((c) => c.place.category == PlaceCategory.food)
          .map((c) => c.place.id)
          .toList();
      final target = foodIds.firstWhere(
        (id) =>
            !plain.stops.any((st) => st.place.id == id) &&
            base.firstWhere((c) => c.place.id == id).distanceKm < 1,
      );
      final boosted = [
        for (final c in base)
          c.place.id == target
              ? PlaceWithDistance(
                  Place.fromJson({
                    ...c.place.toJson(),
                    'tags': [...c.place.tags, 'POPULAR'],
                  }),
                  c.distanceKm,
                )
              : c,
      ];
      final result = const RecommendationEngine().recommend(
        EngineRequest(
          situation: s,
          candidates: boosted,
          areaName: '서울 성수',
          startAt: DateTime(2026, 9, 26, 14, 30),
          maxDistanceKm: 5,
        ),
      );
      expect(result.values.any((c) => c.stops.any((st) => st.place.id == target)), isTrue);
    });

    test('Course json round trip', () {
      final c = _run(_situation())[PlanType.best]!;
      final back = Course.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.signature, c.signature);
      expect(back.totalCost, c.totalCost);
    });
  });
}
