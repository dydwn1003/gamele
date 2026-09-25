import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwohaji/core/utils/geo_utils.dart';
import 'package:mwohaji/features/plan/presentation/widgets/timeline_widgets.dart';
import 'package:mwohaji/features/recommendation/domain/models/course.dart';
import 'package:mwohaji/features/recommendation/domain/models/place.dart';
import 'package:mwohaji/shared_widgets/app_icons.dart';

Place _place(String category, String sub, String name) => Place.fromJson({
  'id': name,
  'name': name,
  'category': category,
  'subcategory': sub,
  'latitude': 37.5,
  'longitude': 127.0,
});

void main() {
  test('subcategory picks a specific icon', () {
    expect(_place('ACTIVITY', '스티커사진', '인생네컷 성수점').icon, Icons.photo_camera_rounded);
    expect(_place('ACTIVITY', '방탈출카페', '비밀의방').icon, Icons.key_rounded);
    expect(_place('ACTIVITY', '보드카페', '레드버튼').icon, Icons.casino_rounded);
    expect(_place('CAFE', '베이커리', '어니언').icon, Icons.bakery_dining_rounded);
    expect(_place('BAR', '와인', '와인바').icon, Icons.wine_bar_rounded);
    expect(_place('PARK', '공원', '뚝섬 공원').icon, Icons.park_rounded);
  });

  test('unknown subcategory falls back to the category icon', () {
    expect(_place('FOOD', '한식', '할매집').icon, PlaceCategory.food.icon);
    expect(_place('ACTIVITY', '기타', '무언가').icon, PlaceCategory.activity.icon);
  });

  testWidgets('timeline shows the specific icon and estimated hours', (tester) async {
    final place = Place.fromJson({
      'id': 'p',
      'name': '비밀의방',
      'category': 'ACTIVITY',
      'subcategory': '방탈출카페',
      'latitude': 37.5,
      'longitude': 127.0,
      'opening_hours': {
        'daily': {'open': '10:00', 'close': '24:00'},
      },
    });
    final start = DateTime(2026, 9, 26, 14);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimelineNode(
              stop: CourseStop(
                place: place,
                start: start,
                end: start.add(const Duration(minutes: 80)),
                cost: 22000,
                travel: TravelEstimate.zero,
              ),
              index: 0,
              isLast: true,
              onSwap: () {},
              onReserve: null,
            ),
          ),
        ),
      ),
    );
    expect(find.text('예상 영업 10:00–24:00 · 방문 전 확인해주세요'), findsOneWidget);
    expect(find.byIcon(Icons.key_rounded), findsWidgets);
  });
}
