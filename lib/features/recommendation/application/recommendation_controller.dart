import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/weather_service.dart';
import '../../situation/application/situation_notifier.dart';
import '../../situation/domain/situation.dart';
import '../data/repositories/place_repository.dart';
import '../domain/models/course.dart';
import '../domain/services/recommendation_engine.dart';

class RecommendationResult {
  const RecommendationResult({
    required this.courses,
    required this.areaName,
    required this.startAt,
    required this.rainProbability,
    required this.source,
    this.relocatedTo,
  });

  final Map<PlanType, Course> courses;
  final String areaName;
  final DateTime startAt;
  final int rainProbability;
  final PlaceDataSource source;
  final String? relocatedTo;

  bool get isEmpty => courses.isEmpty;
}

/// 코스 시작 시각: 지금부터 10분 단위 올림. 늦은 밤/이른 아침이면 11:00으로.
DateTime planStartTime(DateTime now) {
  final rounded = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 10 + 1) * 10);
  if (rounded.hour >= 21) {
    final t = now.add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, 11);
  }
  if (rounded.hour < 9) return DateTime(now.year, now.month, now.day, 11);
  return rounded;
}

class RecommendationController extends AsyncNotifier<RecommendationResult?> {
  final _shownSignatures = <String>{};

  @override
  Future<RecommendationResult?> build() async => null;

  Future<void> generate({bool regenerate = false}) async {
    if (!regenerate) _shownSignatures.clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_run);
  }

  Future<RecommendationResult> _run() async {
    final situation = ref.read(situationProvider);
    if (!situation.isComplete) throw StateError('상황 입력이 완료되지 않았어요');
    final location = situation.location!;
    final startAt = planStartTime(DateTime.now());
    final radiusKm = situation.range!.radiusKm;

    // 계산 중 애니메이션을 충분히 보여주기 위한 최소 대기
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 1400));

    final repo = ref.read(placeRepositoryProvider);
    final candidates = await repo.candidates(location.point, radiusKm: radiusKm);
    final rain = await ref
        .read(weatherServiceProvider)
        .maxRainProbability(candidates.anchor, from: startAt, durationMinutes: situation.time!.minutes);
    final areaName = candidates.relocatedTo ?? location.areaName;

    var courses = const RecommendationEngine().recommend(
      EngineRequest(
        situation: situation,
        candidates: candidates.places,
        areaName: areaName,
        startAt: startAt,
        maxDistanceKm: radiusKm,
        rainProbability: rain,
        excludedSignatures: _shownSignatures,
      ),
    );
    // 다시 생성할 조합이 바닥나면 처음부터 순환
    if (courses.isEmpty && _shownSignatures.isNotEmpty) {
      _shownSignatures.clear();
      courses = const RecommendationEngine().recommend(
        EngineRequest(
          situation: situation,
          candidates: candidates.places,
          areaName: areaName,
          startAt: startAt,
          maxDistanceKm: radiusKm,
          rainProbability: rain,
        ),
      );
    }
    _shownSignatures.addAll(courses.values.map((c) => c.signature));
    await minDelay;

    return RecommendationResult(
      courses: courses,
      areaName: areaName,
      startAt: startAt,
      rainProbability: rain,
      source: candidates.source,
      relocatedTo: candidates.relocatedTo,
    );
  }
}

final recommendationProvider = AsyncNotifierProvider<RecommendationController, RecommendationResult?>(
  RecommendationController.new,
);

/// 결과 화면 탭 선택
class SelectedPlanType extends Notifier<PlanType> {
  @override
  PlanType build() => PlanType.best;

  void select(PlanType t) => state = t;
}

final selectedPlanTypeProvider = NotifierProvider<SelectedPlanType, PlanType>(SelectedPlanType.new);

extension SituationSummary on Situation {
  String get chipsSummary =>
      [companion?.label, time?.label, budget?.label, mood?.label].whereType<String>().join(' · ');
}
