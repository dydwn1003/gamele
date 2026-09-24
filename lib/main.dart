import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.init();
  runApp(
    ProviderScope(overrides: [bootstrapProvider.overrideWithValue(bootstrap)], child: const MwohajiApp()),
  );
}
