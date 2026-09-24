import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// 질문 블록. [visible]이 되면 Slide-down으로 펼쳐지고,
/// [highlightTick]이 바뀌면 흔들리며 코랄색으로 강조된다 (미입력 안내).
class QuestionSection extends StatefulWidget {
  const QuestionSection({
    super.key,
    required this.step,
    required this.label,
    required this.question,
    required this.child,
    required this.visible,
    this.answered = false,
    this.highlightTick = 0,
  });

  final int step;
  final String label;
  final String question;
  final Widget child;
  final bool visible;
  final bool answered;
  final int highlightTick;

  @override
  State<QuestionSection> createState() => _QuestionSectionState();
}

class _QuestionSectionState extends State<QuestionSection> with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  bool _glow = false;

  @override
  void didUpdateWidget(covariant QuestionSection old) {
    super.didUpdateWidget(old);
    if (widget.highlightTick != old.highlightTick && widget.highlightTick > 0) {
      _shake.forward(from: 0);
      setState(() => _glow = true);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _glow = false);
      });
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !widget.visible
          ? const SizedBox(width: double.infinity)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * -10), child: child),
              ),
              child: AnimatedBuilder(
                animation: _shake,
                builder: (context, child) => Transform.translate(
                  offset: Offset(math.sin(_shake.value * math.pi * 5) * 8 * (1 - _shake.value), 0),
                  child: child,
                ),
                child: AnimatedContainer(
                  width: double.infinity,
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(top: AppSpacing.section - 8, bottom: 8),
                  padding: EdgeInsets.all(_glow ? 14 : 0),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.largeAll,
                    color: _glow ? AppColors.primarySoft : Colors.transparent,
                    border: Border.all(color: _glow ? AppColors.primary : Colors.transparent, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.answered ? AppColors.primary : AppColors.primarySoft,
                              borderRadius: AppRadius.smallAll,
                            ),
                            child: Text(
                              widget.answered ? '✓ ${widget.label}' : 'Q${widget.step}. ${widget.label}',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: widget.answered ? Colors.white : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(widget.question, style: AppTypography.subtitle),
                      const SizedBox(height: 14),
                      widget.child,
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
