import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/plan/presentation/pages/plan_detail_page.dart';
import '../../features/plan/presentation/pages/saved_plans_page.dart';
import '../../features/recommendation/presentation/pages/recommendation_result_page.dart';
import '../../features/situation/presentation/pages/situation_input_page.dart';

CustomTransitionPage<void> _fadeSlide(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 160),
  transitionsBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SituationInputPage()),
      GoRoute(
        path: '/result',
        pageBuilder: (_, state) => _fadeSlide(state, const RecommendationResultPage()),
      ),
      GoRoute(
        path: '/plan/:id',
        pageBuilder: (_, state) => _fadeSlide(state, PlanDetailPage(planId: state.pathParameters['id']!)),
      ),
      GoRoute(path: '/saved', pageBuilder: (_, state) => _fadeSlide(state, const SavedPlansPage())),
    ],
  );
});
