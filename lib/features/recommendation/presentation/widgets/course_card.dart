import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared_widgets/gradient_button.dart';
import '../../../../shared_widgets/info_badge.dart';
import '../../../../shared_widgets/place_cover.dart';
import '../../domain/models/course.dart';

/// 결과 카드: 대표 이미지 슬라이더 + 타임라인 미리보기 + 요약 배지 + CTA
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, required this.onProceed, this.proceeding = false});

  final Course course;
  final VoidCallback onProceed;
  final bool proceeding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.largeAll,
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverSlider(course: course),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip('${course.type.emoji} ${course.type.label}'),
                    const SizedBox(width: 6),
                    TagChip('${Fmt.hhmm(course.startAt)} 출발', color: AppColors.secondary),
                  ],
                ),
                const SizedBox(height: 10),
                Text(course.title, style: AppTypography.displaySmall.copyWith(fontSize: 22)),
                const SizedBox(height: 14),
                _TimelinePreview(course: course),
                const SizedBox(height: 18),
                _Badges(course: course),
                const SizedBox(height: 18),
                GradientButton(label: '이 플랜으로 진행하기 →', onTap: onProceed, loading: proceeding, height: 54),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverSlider extends StatefulWidget {
  const _CoverSlider({required this.course});

  final Course course;

  @override
  State<_CoverSlider> createState() => _CoverSliderState();
}

class _CoverSliderState extends State<_CoverSlider> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.course.stops;
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: stops.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => PlaceCover(place: stops[i].place, showLabel: false, emojiSize: 72),
          ),
          // 하단 그라데이션 + 장소명
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x66000000)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          '${_page + 1}. ${stops[_page].place.name}',
                          key: ValueKey(_page),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyBold.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < stops.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(left: 4),
                            width: i == _page ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: i == _page ? 1 : 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.course.areaName.replaceFirst('서울 ', '')} 코스 · ${Fmt.duration(widget.course.totalMinutes)}',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final (i, stop) in course.stops.indexed) {
      if (i > 0) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textMuted),
          ),
        );
      }
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.smallAll),
          child: Text(
            '${stop.place.category.emoji} ${stop.place.name}',
            style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: children);
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final moveLabel = course.usesTransit ? '대중교통 포함' : '도보';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InfoBadge(emoji: '⏱️', label: '총 소요시간', value: Fmt.duration(course.totalMinutes)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InfoBadge(emoji: '💰', label: '1인 예상 비용', value: Fmt.won(course.totalCost)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InfoBadge(
                emoji: course.usesTransit ? '🚌' : '🚶',
                label: '이동 ($moveLabel)',
                value: '${course.travelMinutes}분 · ${Fmt.distance(course.totalDistanceMeters)}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InfoBadge(emoji: '🏠', label: '실내 비율', value: '${course.indoorPercent}%'),
            ),
          ],
        ),
      ],
    );
  }
}
