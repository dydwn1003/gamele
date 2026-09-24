import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_config.dart';

/// 앱 부트스트랩 결과 — main()에서 한 번 만들어 ProviderScope에 주입한다.
class AppBootstrap {
  const AppBootstrap({required this.prefs, required this.sessionId, required this.supabase});

  final SharedPreferences prefs;

  /// 비회원 식별자. RLS가 `x-session-id` 헤더로 본인 플랜만 조회하도록 한다.
  final String sessionId;

  /// Supabase 미설정 또는 초기화 실패 시 null → Mock 모드
  final SupabaseClient? supabase;

  static const _sessionKey = 'session_id';

  static Future<AppBootstrap> init() async {
    final prefs = await SharedPreferences.getInstance();
    var sessionId = prefs.getString(_sessionKey);
    if (sessionId == null) {
      sessionId = const Uuid().v4();
      await prefs.setString(_sessionKey, sessionId);
    }

    SupabaseClient? client;
    if (AppConfig.hasSupabase) {
      try {
        final supabase = await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
          headers: {'x-session-id': sessionId},
        );
        client = supabase.client;
      } catch (e) {
        debugPrint('Supabase init failed, falling back to mock mode: $e');
      }
    }

    return AppBootstrap(prefs: prefs, sessionId: sessionId, supabase: client);
  }
}

final bootstrapProvider = Provider<AppBootstrap>(
  (ref) => throw UnimplementedError('bootstrapProvider must be overridden'),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => ref.watch(bootstrapProvider).supabase);

final prefsProvider = Provider<SharedPreferences>((ref) => ref.watch(bootstrapProvider).prefs);

final sessionIdProvider = Provider<String>((ref) => ref.watch(bootstrapProvider).sessionId);
