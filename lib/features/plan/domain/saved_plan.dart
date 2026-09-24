import '../../recommendation/domain/models/course.dart';

enum FeedbackRating {
  like('LIKE', '좋았어요', '👍'),
  neutral('NEUTRAL', '보통이에요', '😐'),
  dislike('DISLIKE', '별로예요', '👎');

  const FeedbackRating(this.code, this.label, this.emoji);

  final String code;
  final String label;
  final String emoji;
}

enum NextPreference {
  moreActive('MORE_ACTIVE', '더 활동적으로'),
  cheaper('CHEAPER', '더 저렴하게'),
  quieter('QUIETER', '더 조용하게');

  const NextPreference(this.code, this.label);

  final String code;
  final String label;
}

class SavedPlan {
  const SavedPlan({
    required this.course,
    required this.savedAt,
    this.remoteId,
    this.bookmarked = false,
    this.feedback,
  });

  final Course course;
  final DateTime savedAt;

  /// Supabase `plans.id` (원격 저장 성공 시)
  final String? remoteId;

  /// 상세 화면 [저장] 버튼으로 찜한 코스
  final bool bookmarked;
  final FeedbackRating? feedback;

  String get id => course.id;

  SavedPlan copyWith({Course? course, String? remoteId, bool? bookmarked, FeedbackRating? feedback}) =>
      SavedPlan(
        course: course ?? this.course,
        savedAt: savedAt,
        remoteId: remoteId ?? this.remoteId,
        bookmarked: bookmarked ?? this.bookmarked,
        feedback: feedback ?? this.feedback,
      );

  Map<String, dynamic> toJson() => {
    'course': course.toJson(),
    'saved_at': savedAt.toIso8601String(),
    'remote_id': remoteId,
    'bookmarked': bookmarked,
    'feedback': feedback?.name,
  };

  factory SavedPlan.fromJson(Map<String, dynamic> json) => SavedPlan(
    course: Course.fromJson((json['course'] as Map).cast<String, dynamic>()),
    savedAt: DateTime.parse(json['saved_at'] as String),
    remoteId: json['remote_id'] as String?,
    bookmarked: json['bookmarked'] as bool? ?? false,
    feedback: json['feedback'] == null ? null : FeedbackRating.values.byName(json['feedback'] as String),
  );
}
