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

    final accentColor = accent;

    return Material(
      color: background ?? colors.bgTertiary,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        // La banda del acento va superpuesta, no como hijo de un Row: dentro
        // de una lista la altura no está acotada y un Row con `stretch` no
        // sabría hasta dónde estirarse. El recorte del Material la redondea.
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.only(left: accentColor == null ? 0 : 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: colors.border),
                gradient: accentColor == null
                    ? null
                    : LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.45],
                      ),
              ),
              child: Padding(padding: padding, child: child),
            ),
            if (accentColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: accentColor),
              ),
          ],
        ),
      ),
    );
  }
}
