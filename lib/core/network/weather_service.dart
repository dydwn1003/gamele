import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Open-Meteo(무료, 키 불필요)로 코스 시간대의 최대 강수확률을 가져온다.
/// 실패하면 0%로 간주 → 날씨 점수는 모두 1.0 (명세 3.2 "otherwise").
class WeatherService {
  WeatherService([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  Future<int> maxRainProbability(LatLng at, {required DateTime from, required int durationMinutes}) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': at.latitude.toStringAsFixed(4),
        'longitude': at.longitude.toStringAsFixed(4),
        'hourly': 'precipitation_probability',
        'forecast_days': '2',
        'timezone': 'Asia/Seoul',
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return 0;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List).cast<String>();
      final probs = (hourly['precipitation_probability'] as List);
      final until = from.add(Duration(minutes: durationMinutes));
      var maxProb = 0;
      for (var i = 0; i < times.length; i++) {
        final t = DateTime.parse(times[i]);
        final inWindow =
            !t.isBefore(DateTime(from.year, from.month, from.day, from.hour)) && t.isBefore(until);
        final p = probs[i];
        if (inWindow && p is num && p > maxProb) maxProb = p.round();
      }
      return maxProb;
    } catch (_) {
      return 0;
    }
  }
}

final weatherServiceProvider = Provider<WeatherService>((ref) => WeatherService());
