import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared_widgets/gradient_button.dart';
import '../../../../shared_widgets/info_badge.dart';
import '../../../recommendation/data/repositories/place_repository.dart';
import '../../../recommendation/domain/models/course.dart';
import '../../../situation/application/situation_notifier.dart';
import '../../../situation/domain/situation.dart';
import '../../../../core/constants/areas.dart';
import '../../application/plan_providers.dart';
import '../../domain/saved_plan.dart';
import '../widgets/course_map_view.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/navigation_launcher.dart';
import '../widgets/timeline_widgets.dart';

/// 화면 3: 코스 상세 타임라인
class PlanDetailPage extends ConsumerStatefulWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends ConsumerState<PlanDetailPage> {
  int? _swapping;

  Future<void> _swap(Course course, int index) async {
    setState(() => _swapping = index);
    final next = await swapStop(ref.read(placeRepositoryProvider), course, index);
    if (!mounted) return;
    setState(() => _swapping = null);
    if (next == null) {
      _toast('동선에 맞는 다른 장소가 아직 없어요 🥲');
      return;
    }
    await ref.read(savedPlansProvider.notifier).updateCourse(next);
    _toast('${next.stops[index].place.name}(으)로 바꿨어요');
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _share(Course course) async {
    final lines = [
      '🗓️ ${course.title}',
      for (final s in course.stops) '${Fmt.hhmm(s.start)} ${s.place.category.emoji} ${s.place.name}',
      '⏱️ ${Fmt.duration(course.totalMinutes)} · 💰 1인 ${Fmt.won(course.totalCost)}',
      '— 뭐하지? 에서 만든 코스',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n'), subject: course.title));
  }

  Future<void> _reserve(String? url, String name) async {
    final uri = url != null
        ? Uri.parse(url)
        : Uri.https('search.naver.com', '/search.naver', {'query': '$name 예약'});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNaverMap(String name, String address) async {
    final area = address.split(' ').take(3).join(' ');
    final query = Uri.encodeComponent('$name $area'.trim());
    await launchUrl(Uri.parse('https://map.naver.com/p/search/$query'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(savedPlansProvider);
    SavedPlan? plan;
    for (final p in plans) {
      if (p.id == widget.planId) plan = p;
    }
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('코스를 찾을 수 없어요')),
      );
    }
    final course = plan.course;
    final explanation = ref.watch(courseExplanationProvider(course));
    final location = ref.watch(situationProvider).location;
    final userLocation = location?.point;
    final startLabel = location == null || location.source == LocationSource.gps
        ? '현재 위치'
        : '${Areas.shortName(location.areaName)} 출발';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '공유',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _share(course),
          ),
          IconButton(
            tooltip: '저장',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                plan.bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                key: ValueKey(plan.bookmarked),
                color: plan.bookmarked ? AppColors.primary : null,
              ),
            ),
            onPressed: () {
              ref.read(savedPlansProvider.notifier).toggleBookmark(course.id);
              _toast(plan!.bookmarked ? '저장을 취소했어요' : 'My Plan에 저장했어요 🔖');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, 120),
        children: [
          AiSummaryCard(explanation: AsyncValueLike(explanation.value)),
          const SizedBox(height: 16),
          CourseMapView(course: course),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InfoBadge(
                  emoji: '⏱️',
                  label: '⏱️ 총 소요',
                  showEmoji: false,
                  value: Fmt.duration(course.totalMinutes),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoBadge(
                  emoji: '💰',
                  label: '💰 1인 비용',
                  showEmoji: false,
                  value: Fmt.won(course.totalCost),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoBadge(
                  emoji: '🏠',
                  label: '🏠 실내 비율',
                  showEmoji: false,
                  value: '${course.indoorPercent}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text('오늘의 타임라인', style: AppTypography.subtitle),
              const Spacer(),
              Text('${Fmt.hhmm(course.startAt)} – ${Fmt.hhmm(course.endAt)}', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 14),
          for (final (i, stop) in course.stops.indexed) ...[
            if (i > 0) TravelConnector(stop: stop),
            TimelineNode(
              stop: stop,
              index: i,
              isLast: i == course.stops.length - 1,
              swapping: _swapping == i,
              onSwap: () => _swap(course, i),
              onReserve: () => _reserve(stop.place.websiteUrl, stop.place.name),
              onOpenMap: () => _openNaverMap(stop.place.name, stop.place.address),
            ),
          ],
          const SizedBox(height: 20),
          _FinishCard(
            done: plan.feedback != null,
            feedback: plan.feedback,
            onTap: () => showFeedbackSheet(context, plan!),
          ),
          const SizedBox(height: 10),
          if (course.stops.any((s) => s.place.fromNaver))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '장소 정보 출처: 네이버 지역검색',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          Text(
            '* 영업시간·가격은 업종별 예상값이에요. 방문 전 한 번 더 확인해주세요.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          12,
          AppSpacing.gutter,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: GradientButton(
          label: '카카오맵 지도 앱으로 길안내 시작',
          icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
          onTap: () =>
              showNavigationSheet(context, course, userLocation: userLocation, startLabel: startLabel),
        ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({required this.done, required this.feedback, required this.onTap});

  final bool done;
  final FeedbackRating? feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: AppRadius.largeAll,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: AppRadius.largeAll, color: AppColors.primarySoft),
        child: Row(
          children: [
            Text(done ? feedback!.emoji : '🏁', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(done ? '후기 고마워요!' : '코스를 다 돌았나요?', style: AppTypography.bodyBold),
                  Text(
                    done ? '"${feedback!.label}" 로 기록했어요.' : '3초 후기로 다음 추천이 더 똑똑해져요.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            if (!done) const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
