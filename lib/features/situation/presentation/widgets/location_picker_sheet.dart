import 'package:flutter/material.dart';

import '../../../../core/constants/areas.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared_widgets/pressable.dart';

/// 위치 직접 선택 Modal (GPS 권한 거부 시)
Future<Area?> showLocationPicker(
  BuildContext context, {
  String? currentName,
  String? message,
  VoidCallback? onUseGps,
}) {
  return showModalBottomSheet<Area>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _LocationPickerSheet(currentName: currentName, message: message, onUseGps: onUseGps),
  );
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({this.currentName, this.message, this.onUseGps});

  final String? currentName;
  final String? message;
  final VoidCallback? onUseGps;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('어디서 시작할까요?', style: AppTypography.displaySmall),
                const SizedBox(height: 6),
                Text(
                  message ?? '동네를 고르면 그 근처로 코스를 짜드려요.',
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                if (onUseGps != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Pressable(
                      onTap: () {
                        Navigator.pop(context);
                        onUseGps!();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondarySoft,
                          borderRadius: AppRadius.mediumAll,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location_rounded, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              '현재 위치 다시 찾기',
                              style: AppTypography.bodyBold.copyWith(color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.3,
                  children: [
                    for (final area in Areas.all)
                      Pressable(
                        onTap: () => Navigator.pop(context, area),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: currentName == area.name ? AppColors.primarySoft : AppColors.surface,
                            borderRadius: AppRadius.mediumAll,
                            border: Border.all(
                              color: currentName == area.name ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(area.emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Areas.shortName(area.name),
                                      style: AppTypography.bodyBold.copyWith(fontSize: 14, height: 1.2),
                                    ),
                                    Text(
                                      area.hint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
