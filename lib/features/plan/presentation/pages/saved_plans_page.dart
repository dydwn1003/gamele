import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared_widgets/info_badge.dart';
import '../../../../shared_widgets/place_cover.dart';
import '../../../../shared_widgets/pressable.dart';
import '../../application/plan_providers.dart';
import '../../domain/saved_plan.dart';
import '../widgets/feedback_sheet.dart';

/// 저장된 플랜 관리 (My Plan)
class SavedPlansPage extends ConsumerWidget {
  const SavedPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = [...ref.watch(savedPlansProvider)]
      ..sort((a, b) {
        if (a.bookmarked != b.bookmarked) return a.bookmarked ? -1 : 1;
        return b.savedAt.compareTo(a.savedAt);
      });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: const Text('My Plan'),
      ),
      body: plans.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🗺️', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 14),
                    Text('아직 떠난 코스가 없어요', style: AppTypography.subtitle),
                    const SizedBox(height: 6),
                    Text(
                      '마음에 드는 코스로 진행하면 여기에 차곡차곡 쌓여요.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                      child: const Text('오늘 코스 찾으러 가기'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, 32),
              itemCount: plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final plan = plans[i];
                return Dismissible(
                  key: ValueKey(plan.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: AppRadius.largeAll),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) => ref.read(savedPlansProvider.notifier).remove(plan.id),
                  child: _SavedPlanCard(plan: plan),
                );
              },
            ),
    );
  }
}

class _SavedPlanCard extends StatelessWidget {
  const _SavedPlanCard({required this.plan});

  final SavedPlan plan;

  @override
  Widget build(BuildContext context) {
    final course = plan.course;
    return Pressable(
      scale: 0.98,
      onTap: () => context.push('/plan/${plan.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.largeAll,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 74,
              child: Row(
                children: [
                  for (final s in course.stops)
                    Expanded(child: PlaceCover(place: s.place, showLabel: false, emojiSize: 28)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(Fmt.date(course.startAt), style: AppTypography.caption),
                      const Spacer(),
                      if (plan.bookmarked) const TagChip('🔖 저장됨'),
                      if (plan.feedback != null) ...[
                        const SizedBox(width: 6),
                        TagChip(
                          '${plan.feedback!.emoji} ${plan.feedback!.label}',
                          color: AppColors.secondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(course.title, style: AppTypography.displaySmall.copyWith(fontSize: 18)),
                  const SizedBox(height: 6),
                  Text(
                    course.stops.map((s) => s.place.name).join(' → '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '⏱️ ${Fmt.duration(course.totalMinutes)} · 💰 ${Fmt.won(course.totalCost)}',
                    style: AppTypography.caption,
                  ),
                  if (plan.feedback == null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        onPressed: () => showFeedbackSheet(context, plan),
                        child: const Text('코스 어땠나요? 3초 후기 남기기'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
