import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared_widgets/pressable.dart';
import '../../../../shared_widgets/app_icons.dart';
import '../../domain/situation.dart';

/// Q1 동행자 Grid Card Toggle
class CompanionGrid extends StatelessWidget {
  const CompanionGrid({super.key, required this.selected, required this.onSelect});

  final Companion? selected;
  final ValueChanged<Companion> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        for (final c in Companion.values)
          _CompanionCard(
            companion: c,
            selected: selected == c,
            dimmed: selected != null && selected != c,
            onTap: () => onSelect(c),
          ),
      ],
    );
  }
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.companion,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final Companion companion;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppRadius.largeAll,
          gradient: selected ? AppColors.sunsetGradient : null,
          color: selected ? null : AppColors.surface,
          boxShadow: selected ? AppShadows.glow : const [],
          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: dimmed ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.25) : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(companion.icon, size: 24, color: selected ? Colors.white : AppColors.primary),
                ),
              ),
              const Spacer(),
              Text(
                companion.label,
                style: AppTypography.subtitle.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                companion.tagline,
                style: AppTypography.caption.copyWith(
                  color: selected ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선택지 알약 버튼 묶음 (Q2~Q5)
class PillChoices<T> extends StatelessWidget {
  const PillChoices({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
    this.iconOf,
    this.subOf,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final String Function(T)? subOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final o in options)
          _Pill(
            label: labelOf(o),
            icon: iconOf?.call(o),
            sub: subOf?.call(o),
            selected: selected == o,
            onTap: () => onSelect(o),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.icon, this.sub});

  final String label;
  final IconData? icon;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSub = sub != null && sub!.isNotEmpty;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: hasSub ? 10 : 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.background,
          borderRadius: AppRadius.mediumAll,
          border: Border.all(color: selected ? AppColors.textPrimary : AppColors.border, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyBold.copyWith(
                    fontSize: 14,
                    height: 1.25,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (hasSub)
                  Text(
                    sub!,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      height: 1.2,
                      color: selected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 진행 상태 [■■□□□] 2/5 단계
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200 + i * 20),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i < done ? AppColors.ctaGradient : null,
                      color: i < done ? null : AppColors.border,
                    ),
                  ),
                ),
                if (i < total - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            '$done/$total 단계',
            key: ValueKey(done),
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: done == total ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
