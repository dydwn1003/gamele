import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../recommendation/domain/models/course.dart';

/// 코스 전체 경로를 한눈에 보는 요약 지도.
/// API 키 없이 동작하도록 flutter_map + CARTO Light 타일을 사용한다.
class CourseMapView extends StatelessWidget {
  const CourseMapView({super.key, required this.course, this.height = 190});

  final Course course;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = course.stops.map((s) => s.place.point).toList();
    final bounds = LatLngBounds.fromPoints(
      points.length == 1
          ? [points.first, LatLng(points.first.latitude + 0.002, points.first.longitude + 0.002)]
          : points,
    );

    return ClipRRect(
      borderRadius: AppRadius.largeAll,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _PaperMapPainter())),
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(44)),
                backgroundColor: Colors.transparent,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.mwohaji.mwohaji',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4,
                      color: AppColors.primary,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                      pattern: StrokePattern.dashed(segments: const [10, 7]),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final (i, s) in course.stops.indexed)
                      Marker(
                        point: s.place.point,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.ctaGradient,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: AppShadows.soft,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Text(
                '© OpenStreetMap © CARTO',
                style: AppTypography.caption.copyWith(fontSize: 9, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 타일을 불러오지 못해도(오프라인 등) 지도처럼 보이도록 그리는 종이 지도 배경
class _PaperMapPainter extends CustomPainter {
  const _PaperMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF4F1EC));
    final block = Paint()..color = const Color(0xFFECE7DF);
    const cell = 46.0;
    for (var y = -10.0; y < size.height; y += cell) {
      for (var x = ((y / cell).round().isEven ? 0.0 : -cell / 2); x < size.width; x += cell) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 6, y + 6, cell - 12, cell - 12),
            const Radius.circular(6),
          ),
          block,
        );
      }
    }
    final river = Paint()
      ..color = const Color(0xFFD6EAF5)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    final path = ui.Path()
      ..moveTo(0, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.7, size.width, size.height * 0.95);
    canvas.drawPath(path, river);
    final park = Paint()..color = const Color(0xFFDDEFD9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.04, size.height * 0.12, 70, 54),
        const Radius.circular(18),
      ),
      park,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
