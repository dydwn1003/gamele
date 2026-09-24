import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

enum TravelMode { walk, transit }

class TravelEstimate {
  const TravelEstimate({required this.minutes, required this.distanceMeters, required this.mode});

  final int minutes;
  final int distanceMeters;
  final TravelMode mode;

  static const zero = TravelEstimate(minutes: 0, distanceMeters: 0, mode: TravelMode.walk);
}

abstract final class GeoUtils {
  static const _earthRadiusKm = 6371.0;

  /// 보행 속도 4km/h (명세 3.3)
  static const walkingKmh = 4.0;

  /// 이 거리 이하는 도보, 초과는 대중교통으로 간주
  static const walkThresholdKm = 1.5;

  /// 대중교통 평균 속도 + 대기/환승 시간 (근사치)
  static const transitKmh = 18.0;
  static const transitOverheadMinutes = 10;

  /// Haversine 공식
  static double distanceKm(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.sqrt(h));
  }

  /// TravelMinutes = DistanceKM / 4.0 × 60 (도보 기준, 명세 3.3)
  /// 도보로 너무 먼 구간은 대중교통 근사치를 쓴다.
  static TravelEstimate estimate(LatLng from, LatLng to) {
    final km = distanceKm(from, to);
    final meters = (km * 1000).round();
    if (km <= walkThresholdKm) {
      final minutes = math.max(1, (km / walkingKmh * 60).round());
      return TravelEstimate(minutes: minutes, distanceMeters: meters, mode: TravelMode.walk);
    }
    final minutes = (km / transitKmh * 60).round() + transitOverheadMinutes;
    return TravelEstimate(minutes: minutes, distanceMeters: meters, mode: TravelMode.transit);
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
