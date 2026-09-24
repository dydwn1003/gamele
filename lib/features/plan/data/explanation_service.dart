import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_service.dart';
import '../../recommendation/domain/models/course.dart';
import '../../recommendation/domain/services/course_copywriter.dart';

class CourseExplanation {
  const CourseExplanation(this.text, {required this.byAi});

  final String text;
  final bool byAi;
}

/// Edge Function `generate-plan-explanation` 호출.
/// AI는 확정된 코스를 "설명"만 한다 — 장소를 찾거나 추천하지 않는다.
class ExplanationService {
  ExplanationService(this._client);

  final SupabaseClient? _client;

  /// 명세 3.4 LLM Input 구조 그대로
  static Map<String, dynamic> payload(Course course) => {
    'constraints': {
      'companion': course.companion.code,
      'total_budget': course.budget.storedValue,
      'area': course.areaName.replaceFirst('서울 ', ''),
      if (course.mood != null) 'mood': course.mood!.label,
    },
    'confirmed_places': [
      for (final (i, s) in course.stops.indexed)
        {
          'sequence': i + 1,
          'name': s.place.name,
          'category': s.place.category.code,
          'duration': '${s.stayMinutes} min',
          'cost': s.cost,
        },
    ],
  };

  Future<CourseExplanation> explain(Course course) async {
    final client = _client;
    if (client != null) {
      try {
        final res = await client.functions
            .invoke('generate-plan-explanation', body: payload(course))
            .timeout(const Duration(seconds: 20));
        final data = res.data;
        if (data is Map && data['summary'] is String && (data['summary'] as String).isNotEmpty) {
          return CourseExplanation(data['summary'] as String, byAi: true);
        }
      } catch (e) {
        debugPrint('AI explanation failed → local summary: $e');
      }
    }
    return CourseExplanation(CourseCopywriter.localSummary(course), byAi: false);
  }
}

final explanationServiceProvider = Provider<ExplanationService>(
  (ref) => ExplanationService(ref.watch(supabaseClientProvider)),
);
