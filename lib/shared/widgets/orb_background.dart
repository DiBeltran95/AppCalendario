import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo con orbes desenfocados que flotan, como el de las pantallas de acceso
/// de la versión web — pero calculado en GPU, así que se mueve de verdad.
class OrbBackground extends StatefulWidget {
  const OrbBackground({
    super.key,
    required this.colors,
    this.child,
    this.showDotGrid = false,
  });

  /// Un orbe por color. Tres suele ser el punto justo.
  final List<Color> colors;

  final Widget? child;

  /// Retícula de puntos por encima, como en el selector de módulo.
  final bool showDotGrid;

  @override
  State<OrbBackground> createState() => _OrbBackgroundState();
}

class _OrbBackgroundState extends State<OrbBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(
                progress: reduced ? 0 : _controller.value,
                colors: widget.colors,
              ),
            ),
          ),
        ),
        if (widget.showDotGrid)
          const IgnorePointer(child: CustomPaint(painter: _DotGridPainter())),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    // Cada orbe recorre una trayectoria de Lissajous con su propio desfase,
    // de modo que nunca se sincronizan y el conjunto parece orgánico.
    for (var i = 0; i < colors.length; i++) {
      final phase = progress * 2 * math.pi + i * 2.1;
      final radius = size.shortestSide * (0.55 + i * 0.08);

      final cx = size.width * (0.2 + 0.6 * i / math.max(1, colors.length - 1)) +
          math.sin(phase) * size.width * 0.16;
      final cy = size.height * (0.18 + 0.3 * i) +
          math.cos(phase * 0.8) * size.height * 0.1;

      final scale = 1 + math.sin(phase * 0.6) * 0.12;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [colors[i], colors[i].withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius * scale),
        );

      canvas.drawCircle(Offset(cx, cy), radius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.progress != progress || old.colors != colors;
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const spacing = 32.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}
