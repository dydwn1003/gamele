import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/areas.dart';
import '../data/location_service.dart';
import '../domain/situation.dart';

/// 사용자 선택 데이터 관리 (명세의 SituationNotifier)
class SituationNotifier extends Notifier<Situation> {
  @override
  Situation build() => const Situation();

  void selectCompanion(Companion v) => state = state.copyWith(companion: v);
  void selectTime(TimeBudget v) => state = state.copyWith(time: v);
  void selectBudget(Budget v) => state = state.copyWith(budget: v);
  void selectMood(Mood v) => state = state.copyWith(mood: v);
  void selectRange(TravelRange v) => state = state.copyWith(range: v);

  void setLocation(UserLocation location) => state = state.copyWith(location: location);

  /// null이면 '지금 출발'로 되돌린다
  void setDepartAt(DateTime? at) =>
      state = at == null ? state.copyWith(departNow: true) : state.copyWith(departAt: at);

  void selectArea(Area area) =>
      setLocation(UserLocation(point: area.center, areaName: area.name, source: LocationSource.manual));

  /// GPS 위치를 시도하고 실패 사유를 돌려준다. (null = 성공)
  Future<LocationFailure?> locate() async {
    final result = await ref.read(locationServiceProvider).current();
    if (result.location != null) {
      setLocation(result.location!);
      return null;
    }
    // 권한 거부 시 기본값: 서울 성수동 (명세 1.2 예외 케이스)
    if (state.location == null) {
      setLocation(
        UserLocation(
          point: Areas.seongsu.center,
          areaName: Areas.seongsu.name,
          source: LocationSource.fallback,
        ),
      );
    }
    return result.failure;
  }

  void reset() => state = Situation(location: state.location, departAt: state.departAt);
}

final situationProvider = NotifierProvider<SituationNotifier, Situation>(SituationNotifier.new);
