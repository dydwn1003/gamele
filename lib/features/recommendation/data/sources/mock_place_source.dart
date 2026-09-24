import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/place.dart';

/// DB 연결 실패/데이터 부족 시 사용하는 로컬 JSON Mock 데이터
class MockPlaceSource {
  MockPlaceSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/mock/places.json';

  final AssetBundle _bundle;
  List<Place>? _cache;

  Future<List<Place>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await _bundle.loadString(assetPath);
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return _cache = list.map(Place.fromJson).toList(growable: false);
  }
}
