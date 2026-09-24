import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mwohaji/core/network/supabase_service.dart';
import 'package:mwohaji/features/situation/application/situation_notifier.dart';
import 'package:mwohaji/features/situation/data/location_service.dart';
import 'package:mwohaji/features/situation/domain/situation.dart';
import 'package:mwohaji/features/situation/presentation/pages/situation_input_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoGps extends LocationService {
  @override
  Future<LocationResult> current() async => const LocationResult.failure(LocationFailure.denied);
}

void main() {
  testWidgets('progressive form: every option is tappable', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(prefs: prefs, sessionId: 't', supabase: null)),
        locationServiceProvider.overrideWithValue(_NoGps()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SituationInputPage()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    await tap('연인');
    await tap('반나절');
    expect(container.read(situationProvider).time, TimeBudget.halfDay);
    await tap('5만원');
    await tap('인스타/전시');
    await tap('대중교통 30분');
    expect(container.read(situationProvider).isComplete, isTrue);
  });
}
