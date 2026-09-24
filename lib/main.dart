import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/network/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 폰트는 assets/google_fonts 에 번들되어 있어 오프라인에서도 동일하게 보인다.
  GoogleFonts.config.allowRuntimeFetching = false;
  final bootstrap = await AppBootstrap.init();
  runApp(
    ProviderScope(overrides: [bootstrapProvider.overrideWithValue(bootstrap)], child: const MwohajiApp()),
  );
}
