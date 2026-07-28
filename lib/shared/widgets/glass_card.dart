import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Tarjeta con desenfoque de fondo.
///
/// Se reserva para overlays y cabeceras flotantes: usarla dentro de listas que
/// hacen scroll cuesta caro en GPU y no aporta nada visualmente.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.radius = AppRadius.card,
    this.blur = 20,
    this.borderColor,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? borderColor;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Tarjeta opaca estándar de la app: barata, la de uso diario.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.onTap,
    this.onLongPress,
    this.background,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Si se indica, pinta una banda de color en el borde izquierdo, igual que
  /// el `border-left` que identifica las tarjetas en la versión web.
  final Color? accent;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? background;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: background ?? colors.bgTertiary,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: colors.border),
            // La banda se hace con un borde grueso a la izquierda para no
            // añadir un widget extra por tarjeta.
            gradient: accent == null
                ? null
                : LinearGradient(
                    colors: [
                      accent!.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45],
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (accent != null)
                Container(width: 4, color: accent),
              Expanded(child: Padding(padding: padding, child: child)),
            ],
          ),
        ),
      ),
    );
  }
}
