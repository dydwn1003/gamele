import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MwohajiApp extends ConsumerWidget {
  const MwohajiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '뭐하지?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // 태블릿/웹에서도 모바일 비율로 보이도록 폭 제한
        return ColoredBox(
          color: const Color(0xFFF1F2F4),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child),
          ),
        );
      },
    );
  }
}
