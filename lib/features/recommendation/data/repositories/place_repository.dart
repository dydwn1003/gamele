import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/areas.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/models/place.dart';
import '../sources/mock_place_source.dart';

enum PlaceDataSource { remote, mock, mixed }

class CandidateResult {
  const CandidateResult({required this.places, required this.anchor, required this.source, this.relocatedTo});

  final List<PlaceWithDistance> places;

  /// 실제 거리 계산 기준점 (Mock 지역으로 이동했으면 해당 지역 중심)
  final LatLng anchor;
  final PlaceDataSource source;

  /// 주변 데이터가 없어 다른 동네로 옮겨 추천했다면 그 동네 이름
  final String? relocatedTo;
}

/// Supabase RPC ↔ Mock 데이터를 Seamless하게 전환하는 Repository
class PlaceRepository {
  PlaceRepository({this._client, MockPlaceSource? mock}) : _mock = mock ?? MockPlaceSource();

  final SupabaseClient? _client;
  final MockPlaceSource _mock;

  /// `get_places_near_location(lat, lng, radius_meters, category_filter)` 호출
  Future<List<Place>> fetchNearby(LatLng at, {required int radiusMeters, List<String>? categories}) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .rpc<List<dynamic>>(
          'get_places_near_location',
          params: {
            'lat': at.latitude,
            'lng': at.longitude,
            'radius_meters': radiusMeters,
            'category_filter': categories,
          },
        )
        .timeout(const Duration(seconds: 6));
    return rows.cast<Map<String, dynamic>>().map((r) => Place.fromJson(r, fromRemote: true)).toList();
  }

  /// 추천 후보 조회. DB 실패 또는 후보 부족 시 Mock으로 보강한다.
  Future<CandidateResult> candidates(LatLng at, {required double radiusKm}) async {
    var remote = <Place>[];
    try {
      remote = await fetchNearby(at, radiusMeters: (radiusKm * 1000).round());
    } catch (e) {
      debugPrint('Remote place fetch failed → mock fallback: $e');
    }

    List<PlaceWithDistance> within(Iterable<Place> places, LatLng anchor) => [
      for (final p in places)
        if (GeoUtils.distanceKm(anchor, p.point) <= radiusKm)
          PlaceWithDistance(p, GeoUtils.distanceKm(anchor, p.point)),
    ];

    if (remote.length >= AppConfig.minRemoteCandidates) {
      return CandidateResult(places: within(remote, at), anchor: at, source: PlaceDataSource.remote);
    }

    final mock = await _mock.loadAll();
    final merged = {...remote, ...mock}.toList();
    final nearby = within(merged, at);
    if (nearby.length >= AppConfig.minRemoteCandidates) {
      return CandidateResult(
        places: nearby,
        anchor: at,
        source: remote.isEmpty ? PlaceDataSource.mock : PlaceDataSource.mixed,
      );
    }

    // 주변 데이터가 없으면 샘플 데이터가 있는 성수동 기준으로 추천
    final anchor = Areas.seongsu.center;
    return CandidateResult(
      places: within(mock, anchor),
      anchor: anchor,
      source: PlaceDataSource.mock,
      relocatedTo: Areas.seongsu.name,
    );
  }

  /// 코스의 한 장소를 대체할 후보 (같은 카테고리, 가까운 순)
  Future<List<Place>> alternatives(Place target, {required Set<String> excludeIds}) async {
    var pool = <Place>[];
    try {
      pool = await fetchNearby(target.point, radiusMeters: 2000, categories: [target.category.code]);
    } catch (_) {}
    if (pool.length < 3) {
      pool = {...pool, ...await _mock.loadAll()}.toList();
    }
    final list = pool.where((p) => p.category == target.category && !excludeIds.contains(p.id)).toList()
      ..sort(
        (a, b) =>
            GeoUtils.distanceKm(target.point, a.point).compareTo(GeoUtils.distanceKm(target.point, b.point)),
      );
    return list.where((p) => GeoUtils.distanceKm(target.point, p.point) <= 3).take(5).toList();
  }
}

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => PlaceRepository(client: ref.watch(supabaseClientProvider)),
);
