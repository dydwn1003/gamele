/// 빌드 시 `--dart-define`으로 주입되는 환경 설정.
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
/// 값이 없으면 앱은 로컬 Mock 데이터 모드로 동작한다.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Android/iOS 딥링크 `appname` 파라미터 (네이버 지도 요구사항)
  static const appPackageName = 'com.mwohaji.mwohaji';

  /// DB 결과가 이 개수보다 적으면 Mock 데이터로 보강한다.
  static const minRemoteCandidates = 8;

  /// 90일 이상 검증되지 않은 장소는 후보에서 제외 (명세 4.3)
  static const staleAfterDays = 90;
}
