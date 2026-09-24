import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/areas.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared_widgets/pressable.dart';
import '../../../plan/application/plan_providers.dart';
import '../../../situation/application/situation_notifier.dart';
import '../../../../shared_widgets/app_icons.dart';
import '../../../situation/presentation/widgets/depart_time_sheet.dart';
import '../../application/recommendation_controller.dart';
import '../../data/repositories/place_repository.dart';
import '../../domain/models/course.dart';
import '../widgets/course_card.dart';
import '../widgets/route_loading_view.dart';

/// 화면 2: 추천 결과 리스트
class RecommendationResultPage extends ConsumerStatefulWidget {
  const RecommendationResultPage({super.key});

  @override
  ConsumerState<RecommendationResultPage> createState() => _RecommendationResultPageState();
}

class _RecommendationResultPageState extends ConsumerState<RecommendationResultPage> {
  bool _proceeding = false;

  Future<void> _proceed(Course course) async {
    setState(() => _proceeding = true);
    final plan = await ref.read(savedPlansProvider.notifier).start(course);
    if (!mounted) return;
    setState(() => _proceeding = false);
    context.push('/plan/${plan.id}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recommendationProvider);
    final situation = ref.watch(situationProvider);
    final area = async.value?.areaName ?? situation.location?.areaName ?? Areas.seongsu.name;
    final startAt = async.value?.startAt ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$area · ${departLabel(startAt)}', style: AppTypography.subtitle.copyWith(fontSize: 17)),
            Text(situation.chipsSummary, style: AppTypography.caption),
          ],
        ),
      ),
      body: async.isLoading
          ? RouteLoadingView(areaShortName: '${Areas.shortName(area)}동')
          : async.when(
              loading: () => RouteLoadingView(areaShortName: '${Areas.shortName(area)}동'),
              error: (e, _) => _MessageView(
                icon: Icons.sentiment_dissatisfied_rounded,
                title: '코스를 만들지 못했어요',
                body: '잠시 후 다시 시도해주세요.\n($e)',
                primaryLabel: '다시 시도',
                onPrimary: () => ref.read(recommendationProvider.notifier).generate(),
              ),
              data: (result) {
                if (result == null) {
                  return RouteLoadingView(areaShortName: '${Areas.shortName(area)}동');
                }
                if (result.isEmpty) {
                  return _MessageView(
                    icon: Icons.search_off_rounded,
                    title: '조건에 맞는 장소를 찾지 못했어요',
                    body: '선택하신 예산/시간 조건에 맞는 장소를 찾지 못했습니다.\n예산을 늘리거나 이동 범위를 넓혀보세요.',
                    primaryLabel: '조건 변경하기',
                    onPrimary: () => context.pop(),
                  );
                }
                return _ResultBody(result: result, proceeding: _proceeding, onProceed: _proceed);
              },
            ),
    );
  }
}

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.result, required this.proceeding, required this.onProceed});

  final RecommendationResult result;
  final bool proceeding;
  final ValueChanged<Course> onProceed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlanTypeProvider);
    final course = result.courses[selected] ?? result.courses.values.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 4, AppSpacing.gutter, 32),
      children: [
        _PlanTabs(selected: selected, onSelect: ref.read(selectedPlanTypeProvider.notifier).select),
        const SizedBox(height: 14),
        ..._notices(result, departChosen: ref.watch(situationProvider).departAt != null),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: CourseCard(
            key: ValueKey(course.id),
            course: course,
            proceeding: proceeding,
            onProceed: () => onProceed(course),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => context.pop(), child: const Text('조건 변경하기')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(recommendationProvider.notifier).generate(regenerate: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('다른 코스 생성'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _notices(RecommendationResult r, {required bool departChosen}) {
    final notices = <(IconData, String)>[];
    final now = DateTime.now();
    if (!departChosen && !DateUtils.isSameDay(r.startAt, now)) {
      notices.add((
        Icons.nightlight_round,
        '늦은 시간이라 ${departLabel(r.startAt)} 코스로 짰어요. 출발 시간은 홈에서 바꿀 수 있어요.',
      ));
    }
    if (r.relocatedTo != null) {
      notices.add((Icons.explore_rounded, '근처 데이터가 아직 부족해서 ${r.relocatedTo} 코스로 보여드려요.'));
    }
    if (r.rainProbability > 50) {
      notices.add((Icons.umbrella_rounded, '비 소식(${r.rainProbability}%)이 있어 실내 위주로 골랐어요.'));
    }
    if (r.source == PlaceDataSource.mock && r.relocatedTo == null) {
      notices.add((Icons.folder_rounded, '기기에 저장된 데이터로 추천 중이에요. 영업시간·가격은 실제와 다를 수 있어요.'));
    }
    return [
      for (final (icon, text) in notices)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mediumAll),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
              ),
            ],
          ),
        ),
    ];
  }
}

class _PlanTabs extends StatelessWidget {
  const _PlanTabs({required this.selected, required this.onSelect});

  final PlanType selected;
  final ValueChanged<PlanType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mediumAll),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / PlanType.values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: w * selected.index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final t in PlanType.values)
                    Expanded(
                      child: Pressable(
                        onTap: () => onSelect(t),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  t.icon,
                                  key: ValueKey(t == selected),
                                  size: 17,
                                  color: t == selected ? AppColors.primary : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: AppTypography.bodyBold.copyWith(
                                  fontSize: 13.5,
                                  color: t == selected ? AppColors.textPrimary : AppColors.textMuted,
                                ),
                                child: Text(t.label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBubble(icon, size: 72, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}
