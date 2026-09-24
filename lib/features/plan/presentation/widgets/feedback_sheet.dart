import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared_widgets/gradient_button.dart';
import '../../../../shared_widgets/pressable.dart';
import '../../../recommendation/domain/models/place.dart';
import '../../application/plan_providers.dart';
import '../../domain/saved_plan.dart';

/// "오늘 코스 어땠나요?" — 3초 만에 제출하는 피드백
Future<void> showFeedbackSheet(BuildContext context, SavedPlan plan) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FeedbackSheet(plan: plan),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet({required this.plan});

  final SavedPlan plan;

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  FeedbackRating? _rating;
  Place? _best;
  NextPreference? _next;
  bool _sending = false;

  Future<void> _submit() async {
    setState(() => _sending = true);
    await ref
        .read(savedPlansProvider.notifier)
        .submitFeedback(widget.plan.id, rating: _rating!, bestPlace: _best, next: _next);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('소중한 후기 고마워요! 다음 코스에 반영할게요 💌')));
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.plan.course.stops.map((s) => s.place).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘 코스 어땠나요?', style: AppTypography.displaySmall),
            const SizedBox(height: 18),
            Row(
              children: [
                for (final r in FeedbackRating.values) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _rating = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _rating == r ? AppColors.primarySoft : AppColors.surface,
                          borderRadius: AppRadius.largeAll,
                          border: Border.all(
                            color: _rating == r ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            AnimatedScale(
                              scale: _rating == r ? 1.25 : 1,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.elasticOut,
                              child: Text(r.emoji, style: const TextStyle(fontSize: 30)),
                            ),
                            const SizedBox(height: 6),
                            Text(r.label, style: AppTypography.bodyBold.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (r != FeedbackRating.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _rating == null
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 22),
                        Text('가장 좋았던 장소는?', style: AppTypography.bodyBold),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in places)
                              ChoiceChip(
                                label: Text('${p.category.emoji} ${p.name}'),
                                selected: _best == p,
                                onSelected: (_) => setState(() => _best = _best == p ? null : p),
                                showCheckmark: false,
                                selectedColor: AppColors.textPrimary,
                                labelStyle: AppTypography.caption.copyWith(
                                  color: _best == p ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
                                side: const BorderSide(color: AppColors.border),
                                backgroundColor: AppColors.background,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text('다음엔 이렇게 해볼까요? (선택)', style: AppTypography.bodyBold),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final n in NextPreference.values)
                              ChoiceChip(
                                label: Text(n.label),
                                selected: _next == n,
                                onSelected: (_) => setState(() => _next = _next == n ? null : n),
                                showCheckmark: false,
                                selectedColor: AppColors.secondary,
                                labelStyle: AppTypography.caption.copyWith(
                                  color: _next == n ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
                                side: const BorderSide(color: AppColors.border),
                                backgroundColor: AppColors.background,
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            GradientButton(
              label: '후기 보내기',
              disabledLabel: '어땠는지 골라주세요',
              enabled: _rating != null,
              loading: _sending,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
