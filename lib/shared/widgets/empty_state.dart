import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../animations/entrance.dart';

/// Estado vacío con el icono respirando suavemente.
///
/// Un vacío quieto se lee como "algo falló"; uno que respira se lee como
/// "aquí todavía no hay nada", que es lo que queremos decir.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  /// Versión reducida, para paneles pequeños.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = color ?? colors.accent;
    final text = Theme.of(context).textTheme;

    return FadeSlideIn(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: compact ? AppSpacing.xl : AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BreathingIcon(
              icon: icon,
              color: accent,
              size: compact ? 40 : 56,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (title != null) ...[
              Text(
                title!,
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.14),
                  foregroundColor: accent,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  const _BreathingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
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
    final reduced = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = reduced ? 0.5 : _controller.value;
        final eased = 0.5 - 0.5 * math.cos(t * math.pi);
        return Container(
          width: widget.size * 1.9,
          height: widget.size * 1.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.06 + eased * 0.05),
          ),
          child: Center(
            child: Transform.scale(scale: 0.96 + eased * 0.08, child: child),
          ),
        );
      },
      child: Icon(
        widget.icon,
        size: widget.size,
        color: widget.color.withValues(alpha: 0.7),
      ),
    );
  }
}
