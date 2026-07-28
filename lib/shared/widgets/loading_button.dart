import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';

/// Botón principal con gradiente.
///
/// En estado de carga el texto **se transforma** en un indicador dentro del
/// mismo contenedor, en vez de saltar a otro widget: el botón se encoge hasta
/// ser un círculo y sigue siendo el mismo objeto en pantalla.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient,
    this.height = 54,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final List<Color>? gradient;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final gradientColors =
        gradient ?? [colors.accent, colors.accentDark];
    final onGradient =
        gradientColors.first.computeLuminance() > 0.45 ? colors.bgPrimary : Colors.white;

    final disabled = onPressed == null || loading;

    return Center(
      child: AnimatedContainer(
        duration: AppMotion.scale(context, AppMotion.standard),
        curve: AppMotion.emphasizedCurve,
        width: loading ? height : (expanded ? double.infinity : null),
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(loading ? height : AppRadius.input),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius:
                BorderRadius.circular(loading ? height : AppRadius.input),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.scale(context, AppMotion.quick),
                child: loading
                    ? SizedBox(
                        key: const ValueKey('spinner'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(onGradient),
                        ),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 19, color: onGradient),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Text(
                            label,
                            style: text.labelLarge?.copyWith(
                              color: onGradient,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
