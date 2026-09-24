import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared_widgets/info_badge.dart';
import '../../../../shared_widgets/place_cover.dart';
import '../../../recommendation/domain/models/course.dart';
import '../../../recommendation/domain/services/course_copywriter.dart';
import '../../data/explanation_service.dart';

const _timeColumnWidth = 52.0;
const _railWidth = 28.0;

/// 타임라인 Vertical Node (시간 | 레일 | 장소 카드)
class TimelineNode extends StatelessWidget {
  const TimelineNode({
    super.key,
    required this.stop,
    required this.index,
    required this.isLast,
    required this.onSwap,
    required this.onReserve,
    this.onOpenMap,
    this.swapping = false,
  });

  final CourseStop stop;
  final int index;
  final bool isLast;
  final bool swapping;
  final VoidCallback onSwap;
  final VoidCallback? onReserve;

  /// 네이버 지도에서 장소 보기
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final p = stop.place;
    final palette = categoryPalette(p.category);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                Fmt.hhmm(stop.start),
                style: AppTypography.bodyBold.copyWith(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: palette),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: palette.last.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Container(
                key: ValueKey(p.id),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.largeAll),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 86,
                      width: double.infinity,
                      child: PlaceCover(place: p, emojiSize: 40),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.category.emoji} ${p.name}',
                            style: AppTypography.bodyBold.copyWith(fontSize: 16),
                          ),
                          if (p.description != null) ...[
                            const SizedBox(height: 2),
                            Text(p.description!, style: AppTypography.caption),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '소요 ${Fmt.duration(stop.stayMinutes)}  |  ${Fmt.won(stop.cost)}',
                            style: AppTypography.body.copyWith(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (p.reservationRequired)
                                GestureDetector(
                                  onTap: onReserve,
                                  child: const TagChip('⚠️ 예약 필요 · 예약하기', color: AppColors.warning),
                                ),
                              if (p.isPopular) const TagChip('🔥 인기', color: AppColors.primary),
                              if (p.isEvent) const TagChip('✨ 기간 한정', color: AppColors.primary),
                              if (stop.cost == 0) const TagChip('무료', color: AppColors.success),
                              if (p.rating > 0)
                                TagChip('★ ${p.rating.toStringAsFixed(1)}', color: AppColors.textSecondary),
                              if (onOpenMap != null)
                                GestureDetector(
                                  onTap: onOpenMap,
                                  child: const TagChip('N 지도에서 보기', color: Color(0xFF03C75A)),
                                ),
                              _SwapButton(onTap: onSwap, loading: swapping),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap, required this.loading});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.smallAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
            else
              const Icon(Icons.swap_horiz_rounded, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text('장소 변경', style: AppTypography.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// 이동 구간 커넥터 ("v 🚶 도보 8분 (550m)")
class TravelConnector extends StatelessWidget {
  const TravelConnector({super.key, required this.stop});

  final CourseStop stop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: _timeColumnWidth),
        SizedBox(
          width: _railWidth,
          child: Center(child: Container(width: 2, height: 40, color: AppColors.border)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.secondarySoft, borderRadius: BorderRadius.circular(20)),
          child: Text(
            CourseCopywriter.travelLabel(stop.travel),
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF1E88C7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// AI 코스 총평 카드
class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({super.key, required this.explanation});

  final AsyncValueLike<CourseExplanation> explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(gradient: AppColors.aiGradient, borderRadius: AppRadius.largeAll),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.large - 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: AppColors.aiGradient.createShader,
                  child: Text(
                    '✨ AI 코스 노트',
                    style: AppTypography.bodyBold.copyWith(color: Colors.white, fontSize: 14),
                  ),
                ),
                const Spacer(),
                if (explanation.value != null)
                  Text(
                    explanation.value!.byAi ? 'Claude가 쓴 총평' : '코스 데이터 요약',
                    style: AppTypography.caption.copyWith(fontSize: 10.5, color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: explanation.value == null
                  ? Column(
                      key: const ValueKey('skeleton'),
                      children: [
                        for (final w in [1.0, 0.92, 0.6])
                          FractionallySizedBox(
                            widthFactor: w,
                            child: Container(
                              height: 12,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      explanation.value!.text,
                      key: ValueKey(explanation.value!.text),
                      style: AppTypography.body.copyWith(height: 1.65),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riverpod AsyncValue에 의존하지 않는 얇은 래퍼 (위젯 테스트 용이성)
class AsyncValueLike<T> {
  const AsyncValueLike(this.value);

  final T? value;
}
