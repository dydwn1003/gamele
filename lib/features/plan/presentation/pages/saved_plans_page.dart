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
import '../../../../shared_widgets/app_icons.dart';
import '../widgets/delete_plan_sheet.dart';
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
        actions: [
          if (plans.isNotEmpty)
            TextButton(
              onPressed: () => _clearAll(context, ref),
              child: Text(
                '전체 삭제',
                style: AppTypography.bodyBold.copyWith(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: plans.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconBubble(Icons.map_rounded, size: 72),
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
                  onDismissed: (_) => deletePlanWithUndo(ScaffoldMessenger.of(context), ref, plan),
                  child: _SavedPlanCard(plan: plan),
                );
              },
            ),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
        title: Text('저장된 코스를 모두 삭제할까요?', style: AppTypography.subtitle),
        content: Text(
          '삭제 직후에는 되돌릴 수 있어요.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('모두 삭제', style: AppTypography.bodyBold.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final notifier = ref.read(savedPlansProvider.notifier);
    final before = await notifier.clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('코스 ${before.length}개를 삭제했어요'),
          action: SnackBarAction(
            label: '되돌리기',
            textColor: AppColors.primary,
            onPressed: () => notifier.restoreAll(before),
          ),
        ),
      );
  }
}

class _SavedPlanCard extends ConsumerWidget {
  const _SavedPlanCard({required this.plan});

  final SavedPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Expanded(child: PlaceCover(place: s.place, showLabel: false, iconSize: 26)),
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
                      if (plan.bookmarked) const TagChip('저장됨', icon: Icons.bookmark_rounded),
                      if (plan.feedback != null) ...[
                        const SizedBox(width: 6),
                        TagChip(plan.feedback!.label, icon: plan.feedback!.icon, color: AppColors.secondary),
                      ],
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 32,
                        height: 28,
                        child: IconButton(
                          tooltip: '삭제',
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                          onPressed: () => confirmAndDeletePlan(context, ref, plan),
                        ),
                      ),
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
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(Fmt.duration(course.totalMinutes), style: AppTypography.caption),
                      const SizedBox(width: 10),
                      const Icon(Icons.payments_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(Fmt.won(course.totalCost), style: AppTypography.caption),
                    ],
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
