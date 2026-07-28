import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';

/// Franja con la pista de interacción del módulo.
class HintBar extends StatelessWidget {
  const HintBar({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border(
          left: BorderSide(color: colors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.touch_app_rounded, size: 15, color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: colors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera del día seleccionado, con botón para quitar el filtro.
class SelectedDayHeader extends StatelessWidget {
  const SelectedDayHeader({
    super.key,
    required this.dateStr,
    required this.subtitle,
    required this.onClear,
    this.icon = Icons.calendar_today_rounded,
    this.accent,
  });

  final String dateStr;
  final String subtitle;
  final VoidCallback onClear;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final color = accent ?? colors.accent;
    final relative = AppDate.relativeLabel(dateStr);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relative == null
                      ? AppDate.weekdayLong(dateStr)
                      : '$relative · ${AppDate.medium(dateStr)}',
                  style: text.titleSmall,
                ),
                Text(subtitle, style: text.bodySmall?.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: colors.textSecondary,
            tooltip: 'Quitar filtro de día',
          ),
        ],
      ),
    );
  }
}

/// Título de sección dentro de un panel.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.color,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: color ?? colors.accent),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(title, style: text.titleSmall)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Botón de acción a ancho completo, con el estilo tenue que usan los paneles.
class PanelActionButton extends StatelessWidget {
  const PanelActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = color ?? colors.accent;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          backgroundColor: accent.withValues(alpha: 0.06),
          side: BorderSide(color: accent.withValues(alpha: 0.3)),
          minimumSize: const Size(0, 46),
        ),
      ),
    );
  }
}

/// Fila etiqueta / valor, el patrón que más se repite en los resúmenes.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.divider = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  /// Línea punteada arriba, para separar el total.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(top: divider ? AppSpacing.sm : 0),
      margin: EdgeInsets.only(top: divider ? AppSpacing.sm : 0),
      decoration: divider
          ? BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? text.titleSmall
                : text.bodyMedium?.copyWith(fontSize: 13),
          ),
          Text(
            value,
            style: (bold ? text.titleSmall : text.bodyMedium)?.copyWith(
              color: valueColor ?? colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: bold ? 15 : 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip pequeño de estado.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.scale(context, AppMotion.quick),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
