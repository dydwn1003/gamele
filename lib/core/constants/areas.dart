import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

/// 위치 직접 선택 모달과 지역명 표시에 쓰이는 서울 주요 동네.
class Area {
  const Area(this.name, this.emoji, this.center, {this.hint = ''});

  final String name;
  final String emoji;
  final LatLng center;
  final String hint;
}

abstract final class Areas {
  static const seongsu = Area('서울 성수', '🏭', LatLng(37.5446, 127.0557), hint: '감성 카페 · 팝업 · 서울숲');

  static const all = <Area>[
    seongsu,
    Area('서울 연남', '🌿', LatLng(37.5621, 126.9235), hint: '경의선숲길 · 골목 맛집'),
    Area('서울 홍대', '🎸', LatLng(37.5563, 126.9236), hint: '공연 · 전시 · 놀거리'),
    Area('서울 한남', '🍷', LatLng(37.5347, 127.0006), hint: '갤러리 · 와인바'),
    Area('서울 을지로', '🏮', LatLng(37.5662, 126.9910), hint: '힙지로 · 노포'),
    Area('서울 익선동', '🏯', LatLng(37.5742, 126.9899), hint: '한옥 골목 · 디저트'),
    Area('서울 잠실', '🎡', LatLng(37.5112, 127.0981), hint: '석촌호수 · 롯데월드'),
    Area('서울 강남', '🌃', LatLng(37.4979, 127.0276), hint: '쇼핑 · 맛집'),
  ];

  /// 좌표에서 가장 가까운 동네 이름. 3km 밖이면 "내 주변".
  static String nameFor(LatLng point) {
    Area? best;
    var bestKm = double.infinity;
    for (final area in all) {
      final km = GeoUtils.distanceKm(point, area.center);
      if (km < bestKm) {
        bestKm = km;
        best = area;
      }
    }
    if (best == null || bestKm > 3) return '내 주변';
    return best.name;
  }

  /// "서울 성수" → "성수"
  static String shortName(String areaName) => areaName.replaceFirst('서울 ', '');
}
