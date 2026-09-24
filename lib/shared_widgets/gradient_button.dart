import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import 'pressable.dart';

/// 메인 CTA. 비활성 상태에서도 탭을 받아 [onDisabledTap]으로 안내할 수 있다.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.disabledLabel,
    this.onDisabledTap,
    this.loading = false,
    this.height = 58,
    this.icon,
  });

  final String label;
  final String? disabledLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDisabledTap;
  final bool enabled;
  final bool loading;
  final double height;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return Pressable(
      onTap: active ? onTap : onDisabledTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        height: height,
        decoration: BoxDecoration(
          borderRadius: AppRadius.mediumAll,
          color: enabled ? null : AppColors.disabled,
          gradient: enabled ? AppColors.ctaGradient : null,
          boxShadow: enabled ? AppShadows.glow : const [],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Row(
                  key: ValueKey('$enabled$label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Text(
                      enabled ? label : (disabledLabel ?? label),
                      style: AppTypography.bodyBold.copyWith(
                        fontSize: 16,
                        color: enabled ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
