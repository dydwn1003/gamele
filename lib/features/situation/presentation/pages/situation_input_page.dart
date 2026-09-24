import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/areas.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared_widgets/gradient_button.dart';
import '../../../../shared_widgets/pressable.dart';
import '../../../plan/application/plan_providers.dart';
import '../../../recommendation/application/recommendation_controller.dart';
import '../../../recommendation/domain/models/course.dart';
import '../../application/situation_notifier.dart';
import '../../data/location_service.dart';
import '../../domain/situation.dart';
import '../widgets/choice_widgets.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/question_section.dart';

/// 화면 1: 메인 & 대화형 상황 입력 (Progressive Input)
class SituationInputPage extends ConsumerStatefulWidget {
  const SituationInputPage({super.key});

  @override
  ConsumerState<SituationInputPage> createState() => _SituationInputPageState();
}

class _SituationInputPageState extends ConsumerState<SituationInputPage> {
  final _scroll = ScrollController();
  final _keys = List.generate(Situation.totalSteps, (_) => GlobalKey());
  final _highlight = List.filled(Situation.totalSteps, 0);
  bool _locating = false;
  bool _askedManualLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(silent: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _locate({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final failure = await ref.read(situationProvider.notifier).locate();
    if (!mounted) return;
    setState(() => _locating = false);
    if (failure != null && !silent) {
      await _pickLocation(message: _failureMessage(failure));
    }
  }

  String _failureMessage(LocationFailure f) => switch (f) {
    LocationFailure.serviceDisabled => '위치 서비스가 꺼져 있어요. 동네를 직접 골라주세요.',
    LocationFailure.denied || LocationFailure.deniedForever => '위치 권한이 없어 현재 위치를 알 수 없어요. 동네를 직접 골라주세요.',
    LocationFailure.timeout => '현재 위치를 찾지 못했어요. 동네를 직접 골라주세요.',
  };

  Future<void> _pickLocation({String? message}) async {
    _askedManualLocation = true;
    final current = ref.read(situationProvider).location;
    final area = await showLocationPicker(
      context,
      currentName: current?.areaName,
      message: message,
      onUseGps: () => _locate(),
    );
    if (area != null) ref.read(situationProvider.notifier).selectArea(area);
  }

  void _scrollToStep(int step) {
    final ctx = _keys[step].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    }
  }

  /// 선택 직후 다음 질문으로 부드럽게 스크롤
  void _afterSelect(int step) {
    if (step + 1 >= Situation.totalSteps) return;
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      final s = ref.read(situationProvider);
      final next = s.firstMissingStep;
      if (next != null) _scrollToStep(next);
    });
  }

  void _onIncompleteTap() {
    final missing = ref.read(situationProvider).firstMissingStep;
    if (missing == null) return;
    _scrollToStep(missing);
    setState(() => _highlight[missing]++);
  }

  Future<void> _submit() async {
    final s = ref.read(situationProvider);
    // GPS 실패 → 기본값(성수)으로 세팅된 상태면 한 번은 직접 선택 Modal을 띄운다
    if (s.location == null || (s.location!.source == LocationSource.fallback && !_askedManualLocation)) {
      await _pickLocation(message: '현재 위치를 확인할 수 없어요.\n기본값은 서울 성수동이에요. 다른 동네를 골라도 좋아요.');
      if (!mounted) return;
      if (ref.read(situationProvider).location == null) {
        ref.read(situationProvider.notifier).selectArea(Areas.seongsu);
      }
    }
    ref.read(selectedPlanTypeProvider.notifier).select(PlanType.best);
    ref.read(recommendationProvider.notifier).generate();
    if (mounted) context.push('/result');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(situationProvider);
    final n = ref.read(situationProvider.notifier);
    final savedCount = ref.watch(savedPlansProvider).length;

    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(savedCount: savedCount),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LocationChip(location: s.location, loading: _locating, onTap: () => _pickLocation()),
                        const SizedBox(height: 18),
                        const _Greeting(),
                        const SizedBox(height: 22),
                        StepProgress(done: s.answeredCount, total: Situation.totalSteps),
                        QuestionSection(
                          key: _keys[0],
                          step: 1,
                          label: '동행',
                          question: '누구와 함께인가요?',
                          visible: true,
                          answered: s.companion != null,
                          highlightTick: _highlight[0],
                          child: CompanionGrid(
                            selected: s.companion,
                            onSelect: (v) {
                              n.selectCompanion(v);
                              _afterSelect(0);
                            },
                          ),
                        ),
                        QuestionSection(
                          key: _keys[1],
                          step: 2,
                          label: '시간',
                          question: '지금부터 얼마나 시간이 있나요?',
                          visible: s.companion != null,
                          answered: s.time != null,
                          highlightTick: _highlight[1],
                          child: PillChoices<TimeBudget>(
                            options: TimeBudget.values,
                            selected: s.time,
                            labelOf: (v) => v.label,
                            emojiOf: (v) => v.emoji,
                            subOf: (v) => v.sub,
                            onSelect: (v) {
                              n.selectTime(v);
                              _afterSelect(1);
                            },
                          ),
                        ),
                        QuestionSection(
                          key: _keys[2],
                          step: 3,
                          label: '예산',
                          question: '1인당 예상 예산은?',
                          visible: s.time != null,
                          answered: s.budget != null,
                          highlightTick: _highlight[2],
                          child: PillChoices<Budget>(
                            options: Budget.values,
                            selected: s.budget,
                            labelOf: (v) => v.label,
                            onSelect: (v) {
                              n.selectBudget(v);
                              _afterSelect(2);
                            },
                          ),
                        ),
                        QuestionSection(
                          key: _keys[3],
                          step: 4,
                          label: '분위기',
                          question: '오늘은 어떤 기분이에요?',
                          visible: s.budget != null,
                          answered: s.mood != null,
                          highlightTick: _highlight[3],
                          child: PillChoices<Mood>(
                            options: Mood.values,
                            selected: s.mood,
                            labelOf: (v) => v.label,
                            emojiOf: (v) => v.emoji,
                            onSelect: (v) {
                              n.selectMood(v);
                              _afterSelect(3);
                            },
                          ),
                        ),
                        QuestionSection(
                          key: _keys[4],
                          step: 5,
                          label: '이동',
                          question: '어디까지 움직일 수 있나요?',
                          visible: s.mood != null,
                          answered: s.range != null,
                          highlightTick: _highlight[4],
                          child: PillChoices<TravelRange>(
                            options: TravelRange.values,
                            selected: s.range,
                            labelOf: (v) => v.label,
                            emojiOf: (v) => v.emoji,
                            onSelect: n.selectRange,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: s.isComplete
                              ? Padding(
                                  key: const ValueKey('ready'),
                                  padding: const EdgeInsets.only(top: 28),
                                  child: _ReadyCard(situation: s),
                                )
                              : const SizedBox.shrink(key: ValueKey('none')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCta(enabled: s.isComplete, onTap: _submit, onDisabledTap: _onIncompleteTap),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.savedCount});

  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, 12, 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.sunsetGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text('뭐', style: AppTypography.bodyBold.copyWith(color: Colors.white, fontSize: 17)),
          ),
          const SizedBox(width: 8),
          Text('뭐하지?', style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Pressable(
            onTap: () => context.push('/saved'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'My Plan',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (savedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$savedCount',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location, required this.loading, required this.onTap});

  final UserLocation? location;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? '위치 찾는 중…'
        : location == null
        ? '위치 선택'
        : location!.source == LocationSource.fallback
        ? '${location!.areaName} (기본)'
        : location!.source == LocationSource.gps
        ? '${location!.areaName} 근처'
        : location!.areaName;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.secondarySoft, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📍', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              '${Fmt.date(DateTime.now())} · $label',
              style: AppTypography.caption.copyWith(
                color: const Color(0xFF1E88C7),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E88C7)),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  String _mood(DateTime now) {
    final h = now.hour;
    if (h < 11) return '상쾌한 아침이에요 ☀️';
    if (h < 17) return '햇살 좋은 오후예요 🌤️';
    if (h < 21) return '노을 지는 저녁이에요 🌇';
    return '포근한 밤이에요 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_mood(now), style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: AppTypography.display,
            children: [
              const TextSpan(text: '오늘 '),
              TextSpan(
                text: '누구와',
                style: AppTypography.display.copyWith(color: AppColors.primary),
              ),
              const TextSpan(text: '\n시간을 보내시나요?'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.situation});

  final Situation situation;

  @override
  Widget build(BuildContext context) {
    final s = situation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.largeAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('좋아요, 이렇게 찾아볼게요 ✨', style: AppTypography.bodyBold),
          const SizedBox(height: 10),
          Text(
            '${s.companion!.emoji} ${s.companion!.label}와 ${s.time!.label}, '
            '1인 ${s.budget!.label} 안에서 ${s.mood!.label} 분위기로 '
            '${s.range!.label} 거리의 코스를 짜드릴게요.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.enabled, required this.onTap, required this.onDisabledTap});

  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDisabledTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        24,
        AppSpacing.gutter,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background.withValues(alpha: 0), AppColors.background, AppColors.background],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: GradientButton(
        enabled: enabled,
        label: '오늘 코스 골라받기 🚀',
        disabledLabel: '상황을 입력해주세요',
        onTap: onTap,
        onDisabledTap: onDisabledTap,
      ),
    );
  }
}

/// 상단의 은은한 노을빛 배경
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -140,
      left: -80,
      right: -80,
      child: IgnorePointer(
        child: Container(
          height: 620,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, -0.2),
              radius: 0.75,
              colors: [Color(0x33FF8A6B), Color(0x1438B6FF), Color(0x00FFFFFF)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }
}
