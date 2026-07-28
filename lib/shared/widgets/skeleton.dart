import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Bloque gris con un brillo que lo recorre.
///
/// Sustituye a los spinners: mantiene la forma de lo que va a llegar, así la
/// pantalla no salta cuando aparecen los datos.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.chip,
  });

  /// Bloque circular, para avatares e iconos.
  const Skeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = AppRadius.full;

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = colors.bgTertiary;
    final highlight = colors.bgHover;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1 - 2 * (1 - t), 0),
                end: Alignment(1 - 2 * (1 - t) + 0.6, 0),
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Esqueleto del calendario: 7×6 celdas mientras carga el mes.
class CalendarSkeleton extends StatelessWidget {
  const CalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) => const Skeleton(radius: AppRadius.chip),
    );
  }
}

/// Esqueleto genérico de lista de tarjetas.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 3, this.height = 72});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Skeleton(height: height, radius: AppRadius.card),
          ),
      ],
    );
  }
}
