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
    Area('서울 망원', '🌅', LatLng(37.5560, 126.9040), hint: '망원시장 · 한강 노을'),
    Area('서울 을지로', '🏮', LatLng(37.5662, 126.9910), hint: '힙지로 · 노포 · 청계천'),
    Area('서울 익선동', '🏯', LatLng(37.5742, 126.9899), hint: '한옥 골목 · 창덕궁'),
    Area('서울 삼청', '🍂', LatLng(37.5810, 126.9815), hint: '경복궁 · 갤러리 · 북촌'),
    Area('서울 서촌', '🌲', LatLng(37.5800, 126.9700), hint: '통인시장 · 인왕산'),
    Area('서울 한남', '🍷', LatLng(37.5370, 126.9990), hint: '리움 · 남산 · 이태원'),
    Area('서울 용산', '🏛️', LatLng(37.5260, 126.9780), hint: '국립중앙박물관 · 용리단길'),
    Area('서울 신사', '🛍️', LatLng(37.5220, 127.0270), hint: '가로수길 · 도산공원'),
    Area('서울 삼성', '📚', LatLng(37.5115, 127.0590), hint: '코엑스 · 봉은사'),
    Area('서울 잠실', '🎡', LatLng(37.5105, 127.1030), hint: '석촌호수 · 롯데월드'),
    Area('서울 여의도', '🌉', LatLng(37.5265, 126.9300), hint: '더현대 · 한강공원'),
    Area('서울 문래', '⚙️', LatLng(37.5155, 126.8950), hint: '예술 골목 · 선유도'),
    Area('서울 대학로', '🎭', LatLng(37.5815, 127.0030), hint: '연극 · 낙산공원'),
    Area('서울 건대', '🎤', LatLng(37.5410, 127.0690), hint: '커먼그라운드 · 어린이대공원'),
    Area('서울 반포', '🌈', LatLng(37.5080, 126.9970), hint: '달빛무지개분수 · 서래마을'),
  ];

  /// 좌표에서 가장 가까운 동네
  static Area nearest(LatLng point) {
    var best = all.first;
    var bestKm = double.infinity;
    for (final area in all) {
      final km = GeoUtils.distanceKm(point, area.center);
      if (km < bestKm) {
        bestKm = km;
        best = area;
      }
    }
    return best;
  }

  /// 좌표에서 가장 가까운 동네 이름. 3km 밖이면 "내 주변".
  static String nameFor(LatLng point) {
    final best = nearest(point);
    return GeoUtils.distanceKm(point, best.center) > 3 ? '내 주변' : best.name;
  }

  /// "서울 성수" → "성수"
  static String shortName(String areaName) => areaName.replaceFirst('서울 ', '');
}
