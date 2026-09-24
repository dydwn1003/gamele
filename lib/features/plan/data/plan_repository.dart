import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../recommendation/domain/models/course.dart';
import '../domain/saved_plan.dart';

/// 플랜 저장: 로컬(항상) + Supabase `plans` / `plan_items` (가능할 때)
class PlanRepository {
  PlanRepository({required this._prefs, required this._sessionId, this._client});

  static const _key = 'saved_plans_v1';

  final SharedPreferences _prefs;
  final String _sessionId;
  final SupabaseClient? _client;

  List<SavedPlan> loadLocal() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SavedPlan.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('Saved plans corrupted, resetting: $e');
      return [];
    }
  }

  Future<void> saveLocal(List<SavedPlan> plans) =>
      _prefs.setString(_key, jsonEncode(plans.map((p) => p.toJson()).toList()));

  /// Supabase에 플랜 저장. plan_items는 places FK가 있어 DB 장소로만 구성된 코스만 저장한다.
  Future<String?> saveRemote(Course course) async {
    final client = _client;
    if (client == null) return null;
    try {
      final user = client.auth.currentUser;
      final row = await client
          .from('plans')
          .insert({
            'user_id': user?.id,
            'session_id': _sessionId,
            'title': course.title,
            'companion': course.companion.code,
            'total_budget': course.budget.storedValue,
            'total_duration_minutes': course.totalMinutes,
            'total_cost': course.totalCost,
            'total_distance_meters': course.totalDistanceMeters,
            'area_name': course.areaName,
            'plan_type': course.type.code,
            'ai_summary': course.aiSummary,
          })
          .select('id')
          .single()
          .timeout(const Duration(seconds: 6));
      final planId = row['id'] as String;

      if (course.allPlacesRemote) {
        await client
            .from('plan_items')
            .insert([
              for (final (i, s) in course.stops.indexed)
                {
                  'plan_id': planId,
                  'place_id': s.place.id,
                  'sequence': i + 1,
                  'start_time': '${Fmt.hhmm(s.start)}:00',
                  'end_time': '${Fmt.hhmm(s.end)}:00',
                  'estimated_cost': s.cost,
                  'travel_minutes_from_previous': s.travel.minutes,
                  'travel_distance_meters': s.travel.distanceMeters,
                },
            ])
            .timeout(const Duration(seconds: 6));
      }
      return planId;
    } catch (e) {
      debugPrint('Remote plan save failed (kept locally): $e');
      return null;
    }
  }

  Future<bool> submitFeedback({
    required String? remotePlanId,
    required FeedbackRating rating,
    String? bestPlaceId,
    bool bestPlaceIsRemote = false,
    NextPreference? next,
  }) async {
    final client = _client;
    if (client == null || remotePlanId == null) return false;
    try {
      await client
          .from('user_feedback')
          .insert({
            'plan_id': remotePlanId,
            'user_id': client.auth.currentUser?.id,
            'session_id': _sessionId,
            'rating': rating.code,
            'best_place_id': bestPlaceIsRemote ? bestPlaceId : null,
            'next_preference': next?.code,
          })
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      debugPrint('Feedback save failed: $e');
      return false;
    }
  }
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(
    prefs: ref.watch(prefsProvider),
    sessionId: ref.watch(sessionIdProvider),
    client: ref.watch(supabaseClientProvider),
  ),
);
