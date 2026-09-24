import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _won = NumberFormat('#,###', 'en_US');

  static String won(int value) => value == 0 ? '무료' : '${_won.format(value)}원';

  /// 90 → "1시간 30분", 45 → "45분"
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  /// 550 → "550m", 1240 → "1.2km"
  static String distance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  static String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// "토요일 오후"
  static String dayPart(DateTime t) {
    final day = '${_weekdays[t.weekday - 1]}요일';
    final h = t.hour;
    final part = h < 6
        ? '새벽'
        : h < 11
        ? '오전'
        : h < 17
        ? '오후'
        : '저녁';
    return '$day $part';
  }

  static String date(DateTime t) => '${t.month}월 ${t.day}일 (${_weekdays[t.weekday - 1]})';
}
