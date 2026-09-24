import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Loading: 점선 동선 위를 핀이 따라 움직이는 애니메이션
/// ("성수동 최적의 이동 동선 계산 중...")
class RouteLoadingView extends StatefulWidget {
  const RouteLoadingView({super.key, required this.areaShortName});

  final String areaShortName;

  @override
  State<RouteLoadingView> createState() => _RouteLoadingViewState();
}

class _RouteLoadingViewState extends State<RouteLoadingView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  late final Timer _timer;
  var _tip = 0;

  static const _tips = ['영업 중인 곳만 골라내는 중', '예산에 맞는 장소를 추리는 중', '걷기 좋은 동선으로 잇는 중', '날씨까지 살펴보는 중'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted) setState(() => _tip = (_tip + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            height: 150,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _RoutePainter(_c.value)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${widget.areaShortName} 최적의 이동 동선 계산 중...',
            style: AppTypography.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _tips[_tip],
              key: ValueKey(_tip),
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.t);

  final double t;

  static const _emojis = ['🌳', '🍽️', '☕'];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(20, size.height * 0.75)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.05,
        size.width * 0.45,
        size.height * 1.0,
        size.width * 0.62,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.1,
        size.width * 0.85,
        size.height * 0.3,
        size.width - 20,
        size.height * 0.25,
      );

    final metric = path.computeMetrics().first;
    final dash = Paint()
      ..color = AppColors.border
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var d = 0.0; d < metric.length; d += 14) {
      canvas.drawPath(metric.extractPath(d, d + 6), dash);
    }

    // 지나온 길은 코랄로
    final progress = Curves.easeInOut.transform(t);
    final drawn = Paint()
      ..shader = AppColors.ctaGradient.createShader(Offset.zero & size)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), drawn);

    // 정류 지점
    for (var i = 0; i < 3; i++) {
      final at = metric.length * (i / 2);
      final pos = metric.getTangentForOffset(at)!.position;
      final reached = progress >= i / 2 - 0.01;
      canvas.drawCircle(pos, 16, Paint()..color = reached ? AppColors.primarySoft : AppColors.surface);
      final tp = TextPainter(
        text: TextSpan(
          text: _emojis[i],
          style: TextStyle(fontSize: reached ? 16 : 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // 움직이는 핀
    final pin = metric.getTangentForOffset(metric.length * progress)!.position;
    final bounce = math.sin(t * math.pi * 6).abs() * 4;
    canvas.drawCircle(pin.translate(0, 2), 9, Paint()..color = const Color(0x22000000));
    canvas.drawCircle(pin.translate(0, -bounce), 9, Paint()..color = AppColors.primary);
    canvas.drawCircle(pin.translate(0, -bounce), 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.t != t;
}
