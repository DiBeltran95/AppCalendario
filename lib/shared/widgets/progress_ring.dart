import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';

/// Anillo de progreso animado.
///
/// Se usa en presupuestos por categoría, vencimiento de CDT y progreso diario
/// de hábitos. El arco crece desde arriba, en el sentido del reloj.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 56,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.child,
    this.duration = AppMotion.dramatic,
  });

  /// 0..1. Valores mayores se recortan, pero el color de aviso ya lo indica.
  final double progress;

  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ringColor = color ?? colors.accent;
    final track = trackColor ?? colors.bgHover;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : duration,
        curve: AppMotion.reveal,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            color: ringColor,
            trackColor: track,
            strokeWidth: strokeWidth,
          ),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.55), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// Barra de progreso con un brillo que la recorre cuando está avanzada.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
    this.duration = AppMotion.dramatic,
  });

  final double progress;
  final Color? color;
  final double height;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final barColor = color ?? colors.accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.bgHover)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : duration,
              curve: AppMotion.reveal,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        barColor.withValues(alpha: 0.65),
                        barColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
