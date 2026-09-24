import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared_widgets/gradient_button.dart';
import '../../../../shared_widgets/pressable.dart';

/// 출발 시간 선택 결과. [at]이 null이면 '지금 출발'.
class DepartChoice {
  const DepartChoice(this.at);

  final DateTime? at;
}

/// "언제 출발할까요?" 시트. 닫으면 null(변경 없음).
Future<DepartChoice?> showDepartTimeSheet(BuildContext context, {DateTime? current}) {
  return showModalBottomSheet<DepartChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DepartTimeSheet(current: current),
  );
}

/// 표시용 문구: "지금 출발", "오늘 18:30 출발", "내일 11:00 출발"
String departLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return '지금 출발';
  final today = _dateOnly(now ?? DateTime.now());
  final diff = _dateOnly(at).difference(today).inDays;
  final day = switch (diff) {
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    _ => '${at.month}/${at.day}',
  };
  return '$day ${Fmt.hhmm(at)} 출발';
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// 10분 단위로 올림
DateTime _roundUp10(DateTime t) {
  final extra = t.minute % 10 == 0 && t.second == 0 ? 0 : 10 - t.minute % 10;
  return DateTime(t.year, t.month, t.day, t.hour, t.minute).add(Duration(minutes: extra));
}

class _DepartTimeSheet extends StatefulWidget {
  const _DepartTimeSheet({this.current});

  final DateTime? current;

  @override
  State<_DepartTimeSheet> createState() => _DepartTimeSheetState();
}

class _DepartTimeSheetState extends State<_DepartTimeSheet> {
  /// 0 = 지금, 1 = 오늘, 2 = 내일, 3 = 모레
  late int _day;
  late int _minuteOfDay;

  static const _dayLabels = ['지금', '오늘', '내일', '모레'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final current = widget.current;
    if (current == null) {
      _day = 0;
      final r = _roundUp10(now.add(const Duration(minutes: 30)));
      _minuteOfDay = r.hour * 60 + r.minute;
    } else {
      _day = (_dateOnly(current).difference(_dateOnly(now)).inDays + 1).clamp(1, 3);
      _minuteOfDay = current.hour * 60 + current.minute;
    }
  }

  DateTime get _selected {
    final now = DateTime.now();
    final base = _dateOnly(now).add(Duration(days: _day - 1));
    return base.add(Duration(minutes: _minuteOfDay));
  }

  void _selectDay(int i) {
    _day = i;
    final now = DateTime.now();
    if (i >= 2 && (_minuteOfDay < 9 * 60 || _minuteOfDay > 20 * 60)) {
      // 내일·모레는 한밤중 대신 오전 11시부터 제안
      _minuteOfDay = 11 * 60;
    } else if (i == 1 && _isPast) {
      final r = _roundUp10(now);
      _minuteOfDay = r.hour * 60 + r.minute;
    }
  }

  /// 오늘인데 이미 지난 시각이면 고를 수 없다
  bool get _isPast => _day == 1 && _selected.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('언제 출발할까요?', style: AppTypography.displaySmall),
            const SizedBox(height: 4),
            Text(
              '출발 시각에 맞춰 영업 중인 곳으로 코스를 짜드려요.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < _dayLabels.length; i++) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _selectDay(i)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _day == i ? AppColors.textPrimary : AppColors.surface,
                          borderRadius: AppRadius.mediumAll,
                        ),
                        child: Text(
                          _dayLabels[i],
                          style: AppTypography.bodyBold.copyWith(
                            fontSize: 14,
                            color: _day == i ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < _dayLabels.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _day == 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '지금 바로 출발하는 코스를 찾아요. 늦은 밤이면 다음 날 11시 코스로 짜드려요.',
                              style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: CupertinoTheme(
                            data: CupertinoThemeData(
                              textTheme: CupertinoTextThemeData(
                                dateTimePickerTextStyle: AppTypography.subtitle.copyWith(fontSize: 21),
                              ),
                            ),
                            child: CupertinoDatePicker(
                              key: ValueKey(_day),
                              mode: CupertinoDatePickerMode.time,
                              minuteInterval: 10,
                              use24hFormat: true,
                              initialDateTime: DateTime(
                                2000,
                                1,
                                1,
                                _minuteOfDay ~/ 60,
                                _minuteOfDay % 60 ~/ 10 * 10,
                              ),
                              onDateTimeChanged: (t) => setState(() => _minuteOfDay = t.hour * 60 + t.minute),
                            ),
                          ),
                        ),
                        if (_isPast)
                          Text(
                            '이미 지난 시각이에요. 오늘은 ${Fmt.hhmm(_roundUp10(DateTime.now()))} 이후로 골라주세요.',
                            style: AppTypography.caption.copyWith(color: AppColors.error),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: _day == 0 ? '지금 출발할게요' : '${departLabel(_selected)}할게요',
              enabled: !_isPast,
              disabledLabel: '다른 시각을 골라주세요',
              onTap: () => Navigator.pop(context, DepartChoice(_day == 0 ? null : _selected)),
            ),
          ],
        ),
      ),
    );
  }
}
