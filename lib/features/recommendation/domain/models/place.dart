import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// 내부 카테고리 (명세 4.2 정규화 매핑 결과)
enum PlaceCategory {
  park('PARK', '공원/자연', '🌳'),
  exhibition('EXHIBITION', '전시/관람', '🖼️'),
  popup('POPUP', '팝업/행사', '✨'),
  activity('ACTIVITY', '액티비티', '🎯'),
  food('FOOD', '맛집', '🍽️'),
  cafe('CAFE', '카페', '☕'),
  bar('BAR', '바/펍', '🍷');

  const PlaceCategory(this.code, this.label, this.emoji);

  final String code;
  final String label;
  final String emoji;

  static PlaceCategory fromCode(String code) =>
      values.firstWhere((c) => c.code == code.toUpperCase(), orElse: () => PlaceCategory.activity);

  bool get isAttraction => this == park || this == exhibition || this == popup || this == activity;
}

enum IndoorOutdoor {
  indoor('INDOOR'),
  outdoor('OUTDOOR'),
  mixed('MIXED');

  const IndoorOutdoor(this.code);

  final String code;

  static IndoorOutdoor fromCode(String? code) =>
      values.firstWhere((v) => v.code == code?.toUpperCase(), orElse: () => IndoorOutdoor.indoor);

  /// 코스 실내 비율 계산용 가중치
  double get indoorWeight => switch (this) {
    IndoorOutdoor.indoor => 1.0,
    IndoorOutdoor.mixed => 0.5,
    IndoorOutdoor.outdoor => 0.0,
  };
}

class OpeningWindow {
  const OpeningWindow(this.openMinute, this.closeMinute);

  /// 자정 기준 분. close가 open보다 작으면 자정을 넘겨 영업.
  final int openMinute;
  final int closeMinute;

  static int? _parse(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static OpeningWindow? fromJson(Object? json) {
    if (json is! Map) return null;
    final open = _parse(json['open'] as String?);
    final close = _parse(json['close'] as String?);
    if (open == null || close == null) return null;
    return OpeningWindow(open, close);
  }

  /// [startMinute, endMinute] 구간 전체가 영업시간 안에 드는지
  bool covers(int startMinute, int endMinute) {
    final close = closeMinute <= openMinute ? closeMinute + 24 * 60 : closeMinute;
    return startMinute >= openMinute && endMinute <= close;
  }
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    this.subcategory,
    this.description,
    this.phone,
    this.websiteUrl,
    this.imageUrls = const [],
    this.priceMin = 0,
    this.priceMax = 0,
    this.durationMinutes = 60,
    this.indoorOutdoor = IndoorOutdoor.indoor,
    this.tags = const {},
    this.rating = 0,
    this.reviewCount = 0,
    this.openingHours = const {},
    this.reservationRequired = false,
    this.isEvent = false,
    this.fromRemote = false,
  });

  final String id;
  final String name;
  final PlaceCategory category;
  final String? subcategory;
  final String? description;
  final String address;
  final double lat;
  final double lng;
  final String? phone;
  final String? websiteUrl;
  final List<String> imageUrls;
  final int priceMin;
  final int priceMax;
  final int durationMinutes;
  final IndoorOutdoor indoorOutdoor;
  final Set<String> tags;
  final double rating;
  final int reviewCount;

  /// {"mon": {"open": "10:00", "close": "22:00"}, ...} — "daily" 키도 허용
  final Map<String, dynamic> openingHours;
  final bool reservationRequired;

  /// 현재 진행 중인 팝업/행사 여부 (S_nov = 1.0)
  final bool isEvent;

  /// Supabase에서 온 데이터인지 (plan_items FK 저장 가능 여부)
  final bool fromRemote;

  LatLng get point => LatLng(lat, lng);

  /// 네이버 '리뷰 많은 순' 검색에 나온 인기 가게 (ingest-naver-popular)
  bool get isPopular => tags.contains('POPULAR');

  /// 장소 평균 비용 C_i (1인)
  int get avgCost => ((priceMin + priceMax) / 2).round();

  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// 방문 구간 동안 영업 중인지. 영업시간 정보가 없으면 영업 중으로 간주.
  bool isOpenDuring(DateTime start, DateTime end) {
    if (openingHours.isEmpty) return true;
    final dayKey = _dayKeys[start.weekday - 1];
    final raw = openingHours[dayKey] ?? openingHours['daily'];
    if (raw == null) {
      // 요일 정보는 있는데 해당 요일이 없으면 휴무
      return !_dayKeys.any(openingHours.containsKey);
    }
    if (raw == 'closed') return false;
    final window = OpeningWindow.fromJson(raw);
    if (window == null) return true;
    final startMin = start.hour * 60 + start.minute;
    final endMin = startMin + end.difference(start).inMinutes;
    return window.covers(startMin, endMin);
  }

  factory Place.fromJson(Map<String, dynamic> json, {bool fromRemote = false}) {
    List<String> strList(Object? v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    return Place(
      id: json['id'].toString(),
      name: json['name'] as String,
      category: PlaceCategory.fromCode(json['category'] as String),
      subcategory: json['subcategory'] as String?,
      description: json['description'] as String?,
      address: (json['address'] as String?) ?? '',
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      phone: json['phone'] as String?,
      websiteUrl: json['website_url'] as String?,
      imageUrls: strList(json['image_urls']),
      priceMin: (json['price_min'] as num?)?.toInt() ?? 0,
      priceMax: (json['price_max'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      indoorOutdoor: IndoorOutdoor.fromCode(json['indoor_outdoor'] as String?),
      tags: strList(json['tags']).map((t) => t.toUpperCase()).toSet(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      openingHours: (json['opening_hours'] as Map?)?.cast<String, dynamic>() ?? const {},
      reservationRequired: json['reservation_required'] as bool? ?? false,
      isEvent: json['is_event'] as bool? ?? false,
      fromRemote: fromRemote || (json['from_remote'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.code,
    'subcategory': subcategory,
    'description': description,
    'address': address,
    'latitude': lat,
    'longitude': lng,
    'phone': phone,
    'website_url': websiteUrl,
    'image_urls': imageUrls,
    'price_min': priceMin,
    'price_max': priceMax,
    'duration_minutes': durationMinutes,
    'indoor_outdoor': indoorOutdoor.code,
    'tags': tags.toList(),
    'rating': rating,
    'review_count': reviewCount,
    'opening_hours': openingHours,
    'reservation_required': reservationRequired,
    'is_event': isEvent,
    'from_remote': fromRemote,
  };

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place($name, ${category.code})';
}

@immutable
class PlaceWithDistance {
  const PlaceWithDistance(this.place, this.distanceKm);

  final Place place;
  final double distanceKm;
}
