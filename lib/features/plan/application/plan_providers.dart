import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recommendation/data/repositories/place_repository.dart';
import '../../recommendation/domain/models/course.dart';
import '../../recommendation/domain/models/place.dart';
import '../../../core/utils/geo_utils.dart';
import '../data/explanation_service.dart';
import '../data/plan_repository.dart';
import '../domain/saved_plan.dart';

/// 저장된 플랜 목록 (최신순)
class SavedPlansNotifier extends Notifier<List<SavedPlan>> {
  PlanRepository get _repo => ref.read(planRepositoryProvider);

  @override
  List<SavedPlan> build() => ref.read(planRepositoryProvider).loadLocal();

  SavedPlan? byId(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _persist(List<SavedPlan> next) async {
    state = next;
    await _repo.saveLocal(next);
  }

  /// [이 플랜으로 진행하기] — 로컬 + Supabase 저장
  Future<SavedPlan> start(Course course) async {
    final existing = byId(course.id);
    if (existing != null) return existing;
    var plan = SavedPlan(course: course, savedAt: DateTime.now());
    await _persist([plan, ...state]);
    final remoteId = await _repo.saveRemote(course);
    if (remoteId != null) {
      plan = plan.copyWith(remoteId: remoteId);
      await _replace(plan);
    }
    return plan;
  }

  Future<void> _replace(SavedPlan plan) => _persist([for (final p in state) p.id == plan.id ? plan : p]);

  Future<void> updateCourse(Course course) async {
    final plan = byId(course.id);
    if (plan == null) return;
    await _replace(plan.copyWith(course: course));
  }

  Future<void> toggleBookmark(String id) async {
    final plan = byId(id);
    if (plan == null) return;
    await _replace(plan.copyWith(bookmarked: !plan.bookmarked));
  }

  Future<void> remove(String id) => _persist(state.where((p) => p.id != id).toList());

  Future<void> submitFeedback(
    String id, {
    required FeedbackRating rating,
    Place? bestPlace,
    NextPreference? next,
  }) async {
    final plan = byId(id);
    if (plan == null) return;
    await _replace(plan.copyWith(feedback: rating));
    await _repo.submitFeedback(
      remotePlanId: plan.remoteId,
      rating: rating,
      bestPlaceId: bestPlace?.id,
      bestPlaceIsRemote: bestPlace?.fromRemote ?? false,
      next: next,
    );
  }
}

final savedPlansProvider = NotifierProvider<SavedPlansNotifier, List<SavedPlan>>(SavedPlansNotifier.new);

/// 코스별 AI 총평 (코스 id + 장소 조합 기준 캐시)
final courseExplanationProvider = FutureProvider.family<CourseExplanation, Course>((ref, course) async {
  final cached = course.aiSummary;
  if (cached != null && cached.isNotEmpty) return CourseExplanation(cached, byAi: true);
  return ref.read(explanationServiceProvider).explain(course);
});

/// 장소 변경 (Alternative Fetch): 동선상 유사한 다른 장소로 교체하고 시간표를 다시 계산
Future<Course?> swapStop(PlaceRepository repo, Course course, int index) async {
  final target = course.stops[index].place;
  final exclude = course.stops.map((s) => s.place.id).toSet();
  final options = await repo.alternatives(target, excludeIds: exclude);
  if (options.isEmpty) return null;

  for (final candidate in options) {
    final rebuilt = rebuildSchedule(course, index, candidate);
    if (rebuilt != null) return rebuilt;
  }
  return null;
}

Course? rebuildSchedule(Course course, int index, Place replacement) {
  final places = [for (final s in course.stops) s.place]..[index] = replacement;
  var clock = course.startAt;
  final stops = <CourseStop>[];
  for (var i = 0; i < places.length; i++) {
    final p = places[i];
    final travel = i == 0 ? TravelEstimate.zero : GeoUtils.estimate(places[i - 1].point, p.point);
    clock = clock.add(Duration(minutes: travel.minutes));
    final stay = i == index
        ? course.stops[i].stayMinutes.clamp(20, p.durationMinutes)
        : course.stops[i].stayMinutes;
    final end = clock.add(Duration(minutes: stay));
    if (!p.isOpenDuring(clock, end)) return null;
    final cost = course.budget.won == 0 ? p.priceMin : p.avgCost;
    stops.add(
      CourseStop(
        place: p,
        start: clock,
        end: end,
        cost: i == index ? cost : course.stops[i].cost,
        travel: travel,
      ),
    );
    clock = end;
  }
  return course.copyWith(stops: stops, aiSummary: '');
}
