import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../shell/dashboard_controller.dart';
import 'day_content.dart';

/// "Lo que viene": todo lo del mes con nombre y apellido.
///
/// Responde de un vistazo a *quién* cumple años, *qué* festivo cae y *cuánto*
/// hay pendiente, sin obligar a tocar día por día. Se muestra cuando no hay
/// un día seleccionado.
class MonthHighlights extends ConsumerWidget {
  const MonthHighlights({
    super.key,
    required this.module,
    this.maxItems = 8,
    this.title,
  });

  final AppModule module;
  final int maxItems;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    final highlights =
        DayContent.highlightsFor(state.buildDays(), module, colors.accent);

    if (highlights.isEmpty) return const SizedBox.shrink();

    final visible = highlights.take(maxItems).toList();
    final rest = highlights.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title ?? 'Lo que viene en ${AppDate.monthNames[state.month - 1].toLowerCase()}',
                style: text.titleSmall,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${highlights.length}',
                style: text.labelSmall?.copyWith(
                  color: colors.accent,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        for (var i = 0; i < visible.length; i++)
          FadeSlideIn(
            index: i,
            offset: 12,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _HighlightTile(
                highlight: visible[i],
                onTap: () {
                  AppFeedback.select();
                  controller.selectDay(visible[i].dateStr);
                },
              ),
            ),
          ),

        if (rest > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'y $rest ${rest == 1 ? 'cosa más' : 'cosas más'} este mes',
              style: text.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

/// Fila de un elemento destacado: fecha, quién/qué, y contexto.
class _HighlightTile extends StatefulWidget {
  const _HighlightTile({required this.highlight, required this.onTap});

  final DayHighlight highlight;
  final VoidCallback onTap;

  @override
  State<_HighlightTile> createState() => _HighlightTileState();
}

class _HighlightTileState extends State<_HighlightTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final item = widget.highlight;
    final date = AppDate.parse(item.dateStr);
    final relative = AppDate.relativeLabel(item.dateStr);
    final daysAway = AppDate.daysBetween(AppDate.today(), item.dateStr);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppMotion.scale(context, AppMotion.instant),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            // Degradado sutil desde el color del elemento: identifica el tipo
            // sin recurrir a una banda lateral dura.
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                item.color.withValues(alpha: 0.14),
                colors.bgTertiary.withValues(alpha: 0.5),
              ],
            ),
            border: Border.all(color: item.color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              // Bloque de fecha.
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Column(
                  children: [
                    Text(
                      '${date.day}',
                      style: text.titleMedium?.copyWith(
                        color: item.color,
                        height: 1,
                      ),
                    ),
                    Text(
                      AppDate.monthShort[date.month - 1].toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: item.color.withValues(alpha: 0.85),
                        fontSize: 8.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.emoji != null) ...[
                          Text(item.emoji!,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                        ] else ...[
                          Icon(item.icon, size: 13, color: item.color),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            style: text.titleSmall?.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle,
                      style: text.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.trailing != null)
                    Text(
                      item.trailing!,
                      style: text.titleSmall?.copyWith(
                        color: item.color,
                        fontSize: 12.5,
                      ),
                    ),
                  Text(
                    relative ??
                        (daysAway == 0 ? 'hoy' : 'en $daysAway d'),
                    style: text.labelSmall?.copyWith(
                      fontSize: 9.5,
                      color: daysAway <= 1
                          ? item.color
                          : colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
