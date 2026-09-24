import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared_widgets/app_icons.dart';
import '../../application/plan_providers.dart';
import '../../domain/saved_plan.dart';

/// 삭제 확인 시트 → 삭제 → '되돌리기' 스낵바. 삭제했으면 true.
Future<bool> confirmAndDeletePlan(BuildContext context, WidgetRef ref, SavedPlan plan) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBubble(Icons.delete_outline_rounded, color: AppColors.error, size: 44),
            const SizedBox(height: 14),
            Text('이 코스를 삭제할까요?', style: AppTypography.displaySmall),
            const SizedBox(height: 6),
            Text(
              '"${plan.course.title}"이(가) My Plan에서 사라져요.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  await deletePlanWithUndo(ScaffoldMessenger.of(context), ref, plan);
  return true;
}

/// 확인 없이 삭제하고 '되돌리기'를 띄운다 (밀어서 삭제용)
Future<void> deletePlanWithUndo(ScaffoldMessengerState messenger, WidgetRef ref, SavedPlan plan) async {
  final notifier = ref.read(savedPlansProvider.notifier);
  final index = notifier.indexOf(plan.id);
  await notifier.remove(plan.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('코스를 삭제했어요'),
        action: SnackBarAction(
          label: '되돌리기',
          textColor: AppColors.primary,
          onPressed: () => notifier.restore(plan, index),
        ),
      ),
    );
}
