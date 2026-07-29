import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/widgets/app_feedback.dart';

/// Una pastilla de resumen dentro de la cabecera del día.
class DaySummaryChip {
  const DaySummaryChip({
    required this.label,
    required this.color,
    this.icon,
    this.emoji,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? emoji;
}

/// Cabecera del día seleccionado.
///
/// Sustituye a la franja de una línea que había antes: el día pasa a ser el
/// protagonista —número grande, día de la semana, mes— y debajo van pastillas
/// que resumen qué hay, para saber de un golpe si el día es festivo, si
/// alguien cumple años o cuánto dinero se movió.
class DayDetailHeader extends StatelessWidget {
  const DayDetailHeader({
    super.key,
    required this.dateStr,
    required this.onClear,
    this.chips = const [],
    this.accent,
    this.emptyLabel = 'Sin nada programado',
  });

  final String dateStr;
  final VoidCallback onClear;
  final List<DaySummaryChip> chips;

  /// Color que define el carácter del día. Por defecto, el del módulo.
  final Color? accent;

  /// Qué decir cuando no hay ninguna pastilla.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tone = accent ?? colors.accent;

    final date = AppDate.parse(dateStr);
    final relative = AppDate.relativeLabel(dateStr);
    final weekday = AppDate.weekdayNames[date.weekday % 7];

    return TweenAnimationBuilder<double>(
      key: ValueKey(dateStr),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.scale(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          // El degradado tiñe la cabecera del carácter del día sin llegar a
          // competir con el contenido que viene debajo.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tone.withValues(alpha: 0.20),
              tone.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(color: tone.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número del día, protagonista.
                Text(
                  '${date.day}',
                  style: text.displaySmall?.copyWith(
                    fontSize: 46,
                    height: 0.95,
                    color: tone,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weekday.toUpperCase(),
                          style: text.labelSmall?.copyWith(
                            color: tone,
                            letterSpacing: 1.6,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${AppDate.monthNames[date.month - 1]} ${date.year}',
                          style: text.bodyMedium?.copyWith(fontSize: 13),
                        ),
                        if (relative != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tone.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              relative.toUpperCase(),
                              style: text.labelSmall?.copyWith(
                                color: tone,
                                fontSize: 9.5,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    AppFeedback.select();
                    onClear();
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: colors.textSecondary,
                  tooltip: 'Quitar selección',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            if (chips.isEmpty)
              Text(
                emptyLabel,
                style: text.bodySmall?.copyWith(fontSize: 12),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final chip in chips) _SummaryChip(chip: chip),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.chip});

  final DaySummaryChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: chip.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: chip.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip.emoji != null)
            Text(chip.emoji!, style: const TextStyle(fontSize: 12))
          else if (chip.icon != null)
            Icon(chip.icon, size: 13, color: chip.color),
          const SizedBox(width: 5),
          Text(
            chip.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: chip.color,
            ),
          ),
        ],
      ),
    );
  }
}
