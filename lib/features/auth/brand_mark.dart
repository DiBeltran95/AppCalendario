import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Logo de la app, con halo, partículas y brillo opcionales.
///
/// Es un [Hero] con etiqueta fija: así el logo del splash no se desvanece al
/// entrar al login, sino que viaja hasta su nueva posición.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 96,
    this.shimmer = false,
    this.particles = false,
    this.heroTag = 'brand-mark',
  });

  final double size;

  /// Brillo diagonal que recorre el logo, para las esperas.
  final bool shimmer;

  /// Partículas orbitando, como la animación de la pantalla de login web.
  final bool particles;

  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;

    Widget logo = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Si el asset faltara, la marca cae a un icono en vez de romper la vista.
      errorBuilder: (context, _, __) => Icon(
        Icons.calendar_month_rounded,
        size: size * 0.8,
        color: accent,
      ),
    );

    if (shimmer) logo = _Shimmer(child: logo);

    return Hero(
      tag: heroTag ?? 'brand-mark',
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: size * 1.7,
          height: size * 1.7,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Halo(color: accent, size: size * 1.7),
              if (particles) _Particles(color: accent, size: size * 1.7),
              logo,
            ],
          ),
        ),
      ),
    );
  }
}

/// Halo que late detrás del logo.
class _Halo extends StatefulWidget {
  const _Halo({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_Halo> createState() => _HaloState();
}

class _HaloState extends State<_Halo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size * (0.85 + t * 0.15),
          height: widget.size * (0.85 + t * 0.15),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withValues(alpha: 0.10 + t * 0.10),
                widget.color.withValues(alpha: 0),
              ],
              stops: const [0.2, 1],
            ),
          ),
        );
      },
    );
  }
}

/// Brillo diagonal que cruza el logo.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final t = _controller.value * 2 - 0.5;
          return LinearGradient(
            begin: Alignment(t - 0.6, -1),
            end: Alignment(t + 0.6, 1),
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.35),
              Colors.transparent,
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Partículas orbitando alrededor del logo.
class _Particles extends StatefulWidget {
  const _Particles({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_Particles> createState() => _ParticlesState();
}

class _ParticlesState extends State<_Particles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _ParticlePainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const int _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * 0.36;

    for (var i = 0; i < _count; i++) {
      // Cada partícula tiene su propia velocidad y radio, derivados del índice,
      // para que el conjunto no parezca un engranaje girando.
      final seed = i / _count;
      final speed = 0.6 + (i % 4) * 0.22;
      final angle = (progress * speed + seed) * 2 * math.pi;
      final wobble = math.sin(angle * 2 + i) * size.shortestSide * 0.05;
      final radius = baseRadius + wobble;

      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius * 0.92,
      );

      final fade = 0.25 + 0.45 * (0.5 + 0.5 * math.sin(angle * 1.5));
      final paint = Paint()..color = color.withValues(alpha: fade);
      canvas.drawCircle(offset, 1.4 + (i % 3) * 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
