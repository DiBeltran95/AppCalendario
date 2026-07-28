import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/orb_background.dart';
import '../auth/brand_mark.dart';

/// Pantalla de arranque.
///
/// Mientras se lee el almacenamiento seguro, el logo entra con un rebote y un
/// brillo lo recorre. La marca es un [Hero], así que al pasar al login no
/// desaparece: viaja hasta su nueva posición.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.dramatic,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: OrbBackground(
        colors: [
          colors.accent.withValues(alpha: 0.22),
          AppColors.info.withValues(alpha: 0.16),
          colors.accentLight.withValues(alpha: 0.12),
        ],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = CurvedAnimation(
                    parent: _controller,
                    curve: AppMotion.overshoot,
                  ).value;
                  return Opacity(
                    opacity: _controller.value.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                  );
                },
                child: const BrandMark(size: 108, shimmer: true),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.45, 1, curve: Curves.easeOut),
                ),
                child: Text(
                  'Agendaservi',
                  style: text.headlineSmall?.copyWith(letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.6, 1, curve: Curves.easeOut),
                ),
                child: Text(
                  'Tu agenda, tus finanzas, tu bienestar',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
