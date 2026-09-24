import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared_widgets/pressable.dart';
import '../../../recommendation/domain/models/course.dart';

enum MapApp {
  kakao('카카오맵', Color(0xFFFEE500), Color(0xFF191919)),
  naver('네이버 지도', Color(0xFF03C75A), Colors.white);

  const MapApp(this.label, this.color, this.onColor);

  final String label;
  final Color color;
  final Color onColor;
}

class NavPoint {
  const NavPoint(this.name, this.point);

  final String name;
  final LatLng point;
}

/// 외부 지도 앱 Deep Link + 웹 Fallback
abstract final class NavigationLauncher {
  static Uri appUri(MapApp app, NavPoint from, NavPoint to, {bool walk = false}) => switch (app) {
    MapApp.kakao => Uri.parse(
      'kakaomap://route?sp=${from.point.latitude},${from.point.longitude}'
      '&ep=${to.point.latitude},${to.point.longitude}&by=${walk ? 'FOOT' : 'PUBLICTRANSIT'}',
    ),
    MapApp.naver => Uri.parse(
      'nmap://route/${walk ? 'walk' : 'public'}?slat=${from.point.latitude}&slng=${from.point.longitude}'
      '&sname=${Uri.encodeComponent(from.name)}'
      '&dlat=${to.point.latitude}&dlng=${to.point.longitude}'
      '&dname=${Uri.encodeComponent(to.name)}&appname=${AppConfig.appPackageName}',
    ),
  };

  static Uri webUri(MapApp app, NavPoint from, NavPoint to) => switch (app) {
    MapApp.kakao => Uri.parse(
      'https://map.kakao.com/link/from/${Uri.encodeComponent(from.name)},${from.point.latitude},${from.point.longitude}'
      '/to/${Uri.encodeComponent(to.name)},${to.point.latitude},${to.point.longitude}',
    ),
    MapApp.naver => Uri.parse(
      'https://map.naver.com/index.nhn?slng=${from.point.longitude}&slat=${from.point.latitude}'
      '&stext=${Uri.encodeComponent(from.name)}&elng=${to.point.longitude}&elat=${to.point.latitude}'
      '&etext=${Uri.encodeComponent(to.name)}&menu=route&pathType=${0}',
    ),
  };

  /// 앱이 설치되어 있으면 앱으로, 아니면 웹 지도로 연다.
  static Future<bool> launch(MapApp app, NavPoint from, NavPoint to, {bool walk = false}) async {
    final appLink = appUri(app, from, to, walk: walk);
    try {
      if (await canLaunchUrl(appLink) && await launchUrl(appLink, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}
    return launchUrl(webUri(app, from, to), mode: LaunchMode.externalApplication);
  }
}

/// 길안내 Sheet: 지도 앱 선택 + 구간 선택
Future<void> showNavigationSheet(
  BuildContext context,
  Course course, {
  LatLng? userLocation,
  String startLabel = '현재 위치',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NavigationSheet(course: course, userLocation: userLocation, startLabel: startLabel),
  );
}

class _NavigationSheet extends StatefulWidget {
  const _NavigationSheet({required this.course, required this.startLabel, this.userLocation});

  final Course course;
  final LatLng? userLocation;
  final String startLabel;

  @override
  State<_NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends State<_NavigationSheet> {
  var _app = MapApp.kakao;

  @override
  Widget build(BuildContext context) {
    final stops = widget.course.stops;
    final legs = <(NavPoint, NavPoint, bool)>[
      if (widget.userLocation != null)
        (
          NavPoint(widget.startLabel, widget.userLocation!),
          NavPoint(stops.first.place.name, stops.first.place.point),
          GeoUtils.distanceKm(widget.userLocation!, stops.first.place.point) <= GeoUtils.walkThresholdKm,
        ),
      for (var i = 1; i < stops.length; i++)
        (
          NavPoint(stops[i - 1].place.name, stops[i - 1].place.point),
          NavPoint(stops[i].place.name, stops[i].place.point),
          stops[i].travel.distanceMeters < 1500,
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('길안내 시작', style: AppTypography.displaySmall),
            const SizedBox(height: 4),
            Text('구간을 누르면 지도 앱으로 바로 연결돼요.', style: AppTypography.caption),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final app in MapApp.values) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _app = app),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _app == app ? app.color : AppColors.surface,
                          borderRadius: AppRadius.mediumAll,
                        ),
                        child: Text(
                          app.label,
                          style: AppTypography.bodyBold.copyWith(
                            color: _app == app ? app.onColor : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (app != MapApp.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            for (final (i, (from, to, walk)) in legs.indexed)
              Pressable(
                onTap: () => NavigationLauncher.launch(_app, from, to, walk: walk),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: AppRadius.mediumAll,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          '${i + 1}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${from.name} → ${to.name}',
                          style: AppTypography.bodyBold.copyWith(fontSize: 14),
                        ),
                      ),
                      Icon(
                        walk ? Icons.directions_walk_rounded : Icons.directions_bus_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.north_east_rounded, size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
