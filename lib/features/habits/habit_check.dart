import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_motion.dart';

/// Checkbox circular de hábito.
///
/// Al marcarlo, una onda llena el círculo desde el centro y el check se dibuja
/// con trazo; al desmarcar, todo se revierte. Es la micro-interacción insignia
/// del módulo de hábitos.
class HabitCheck extends StatefulWidget {
  const HabitCheck({
    super.key,
    required this.checked,
    required this.color,
    required this.onChanged,
    this.size = 30,
  });

  final bool checked;
  final Color color;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  State<HabitCheck> createState() => _HabitCheckState();
}

class _HabitCheckState extends State<HabitCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    value: widget.checked ? 1 : 0,
  );

  @override
  void didUpdateWidget(HabitCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      widget.checked ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.checked),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Área táctil de 48dp aunque el círculo sea menor.
        padding: EdgeInsets.all(math.max(0, (48 - widget.size) / 2)),
        child: reduced
            ? _StaticCheck(checked: widget.checked, color: widget.color, size: widget.size)
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _HabitCheckPainter(
                    progress: AppMotion.emphasizedCurve
                        .transform(_controller.value),
                    color: widget.color,
                  ),
                ),
              ),
      ),
    );
  }
}

class _StaticCheck extends StatelessWidget {
  const _StaticCheck({
    required this.checked,
    required this.color,
    required this.size,
  });

  final bool checked;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? color : Colors.transparent,
        border: Border.all(color: checked ? color : color.withValues(alpha: 0.5), width: 2),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : null,
    );
  }
}

class _HabitCheckPainter extends CustomPainter {
  const _HabitCheckPainter({required this.progress, required this.color});

  /// 0 = vacío, 1 = marcado.
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Borde.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.lerp(color.withValues(alpha: 0.45), color, progress)!,
    );

    // Onda de relleno desde el centro.
    if (progress > 0) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius - 2)),
      );
      canvas.drawCircle(
        center,
        (radius - 1) * Curves.easeOutQuad.transform(progress),
        Paint()..color = color,
      );
      canvas.restore();
    }

    // Check dibujado con trazo, en la segunda mitad de la animación.
    final checkT = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
    if (checkT > 0) {
      final path = Path()
        ..moveTo(size.width * 0.28, size.height * 0.53)
        ..lineTo(size.width * 0.44, size.height * 0.68)
        ..lineTo(size.width * 0.73, size.height * 0.35);

      for (final metric in path.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * checkT),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      }
    }

    // Micro-burst de partículas al completar.
    if (progress > 0.75) {
      final burstT = (progress - 0.75) / 0.25;
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - burstT) * 0.8);
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final distance = radius + 3 + burstT * 7;
        canvas.drawCircle(
          Offset(
            center.dx + math.cos(angle) * distance,
            center.dy + math.sin(angle) * distance,
          ),
          1.5 * (1 - burstT),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HabitCheckPainter old) =>
      old.progress != progress || old.color != color;
}
