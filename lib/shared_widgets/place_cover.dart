import 'package:flutter/material.dart';

import '../core/theme/app_typography.dart';
import '../features/recommendation/domain/models/place.dart';
import 'app_icons.dart';

/// 카테고리별 감성 그라데이션 팔레트
List<Color> categoryPalette(PlaceCategory c) => switch (c) {
  PlaceCategory.park => const [Color(0xFF9BE3B5), Color(0xFF48C78E)],
  PlaceCategory.exhibition => const [Color(0xFFD9C8FF), Color(0xFF8E7BFF)],
  PlaceCategory.popup => const [Color(0xFFFFC7D9), Color(0xFFFF7EA6)],
  PlaceCategory.activity => const [Color(0xFFFFD59E), Color(0xFFFF9B54)],
  PlaceCategory.food => const [Color(0xFFFFB3A7), Color(0xFFFF5A5F)],
  PlaceCategory.cafe => const [Color(0xFFF3DCC4), Color(0xFFC89F7C)],
  PlaceCategory.bar => const [Color(0xFF8C9DFF), Color(0xFF3D3B8E)],
};

/// 장소 대표 이미지. 사진이 없거나 로딩 실패 시 카테고리 일러스트 커버로 대체.
class PlaceCover extends StatelessWidget {
  const PlaceCover({super.key, required this.place, this.showLabel = true, this.iconSize = 64});

  final Place place;
  final bool showLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final art = _IllustratedCover(place: place, showLabel: showLabel, iconSize: iconSize);
    if (place.imageUrls.isEmpty) return art;
    return Stack(
      fit: StackFit.expand,
      children: [
        art,
        Image.network(
          place.imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _IllustratedCover extends StatelessWidget {
  const _IllustratedCover({required this.place, required this.showLabel, required this.iconSize});

  final Place place;
  final bool showLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = categoryPalette(place.category);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 부드러운 빛 번짐 원들
              Positioned(
                right: -w * 0.15,
                top: -h * 0.3,
                child: _Orb(size: h * 0.9, color: Colors.white.withValues(alpha: 0.22)),
              ),
              Positioned(
                left: -w * 0.1,
                bottom: -h * 0.35,
                child: _Orb(size: h * 0.8, color: colors.last.withValues(alpha: 0.35)),
              ),
              Positioned(
                left: w * 0.55,
                bottom: h * 0.15,
                child: _Orb(size: h * 0.12, color: Colors.white.withValues(alpha: 0.5)),
              ),
              // 반투명 유리 원 위의 카테고리 아이콘
              Center(
                child: Container(
                  width: iconSize * 1.25,
                  height: iconSize * 1.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(place.category.icon, size: iconSize * 0.62, color: Colors.white),
                ),
              ),
              if (showLabel)
                Positioned(
                  left: 16,
                  bottom: 14,
                  right: 16,
                  child: Text(
                    place.subcategory ?? place.category.label,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
