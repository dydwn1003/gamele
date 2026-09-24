/// 빌드 시 `--dart-define`으로 주입되는 환경 설정.
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
/// 기본값은 뭐하지 Supabase 프로젝트다. 값이 비어 있으면 로컬 Mock 데이터 모드로 동작한다.
abstract final class AppConfig {
  // anon 키는 앱에 들어가는 공개용 키다. 데이터 보호는 RLS 정책이 담당한다.
  // 샘플 데이터로만 실행하려면 --dart-define=SUPABASE_URL= 처럼 빈 값을 넘긴다.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qnstarseobbwbeeoqcmy.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuc3RhcnNlb2Jid2JlZW9xY215Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAyNjQ1NDksImV4cCI6MjEwNTg0MDU0OX0.Kb-jL7XFRIu97i63HZ2cE95uFCAQGlVUjmtVI1N0TbA',
  );

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Android/iOS 딥링크 `appname` 파라미터 (네이버 지도 요구사항)
  static const appPackageName = 'com.mwohaji.mwohaji';

  /// DB 결과가 이 개수보다 적으면 Mock 데이터로 보강한다.
  static const minRemoteCandidates = 8;

  /// 90일 이상 검증되지 않은 장소는 후보에서 제외 (명세 4.3)
  static const staleAfterDays = 90;
}
