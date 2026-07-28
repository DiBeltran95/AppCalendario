import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/cycle/cycle_engine.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/cycle.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/panel_parts.dart';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/skeleton.dart';
import '../shell/dashboard_controller.dart';
import 'cycle_sheet.dart';
import 'cycle_wheel.dart';

/// Panel del módulo Salud Femenina.
class CyclePanel extends ConsumerWidget {
  const CyclePanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    final stats = state.cycleStats;
    // Día a analizar: el seleccionado, u hoy.
    final targetDay = state.selectedDay ?? AppDate.today();
    final details =
        stats.isEmpty ? null : CycleEngine.detailsFor(targetDay, stats);
    final history = CycleEngine.history(state.bootstrap.cycles);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        HintBar(text: AppModule.cycle.hint, icon: Icons.favorite_rounded),
        const SizedBox(height: AppSpacing.lg),

        if (state.selectedDay != null) ...[
          SelectedDayHeader(
            dateStr: state.selectedDay!,
            subtitle: details?.phase.label ?? 'Fuera del rango analizable',
            icon: Icons.water_drop_rounded,
            accent: details?.phase.color ?? AppColors.phasePeriod,
            onClear: controller.clearSelection,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (state.loading)
          const ListSkeleton(count: 3)
        else if (stats.isEmpty)
          EmptyState(
            icon: Icons.spa_rounded,
            title: 'Empieza a conocer tu ciclo',
            message:
                'Registra el primer día de tu periodo y el calendario calculará tus fases, tu ventana fértil y tu próxima fecha.',
            actionLabel: 'Registrar periodo',
            color: AppColors.phasePeriod,
            onAction: () => showCycleSheet(context, dateStr: targetDay),
            compact: true,
          )
        else if (details == null)
          EmptyState(
            icon: Icons.spa_rounded,
            title: 'Fuera de rango',
            message:
                'Este día es anterior a tu primer registro o está demasiado lejos para predecirlo con honestidad.',
            color: AppColors.phasePeriod,
            compact: true,
          )
        else ...[
          // La rueda, protagonista del panel.
          FadeSlideIn(
            child: Center(child: CycleWheel(details: details)),
          ),
          const SizedBox(height: AppSpacing.lg),

          FadeSlideIn(index: 1, child: _PhaseCard(details: details)),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(index: 2, child: _NextPeriodCard(details: details)),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(
            index: 3,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    title: 'Leyenda',
                    icon: Icons.palette_rounded,
                    color: AppColors.phasePeriod,
                  ),
                  const CycleLegend(),
                ],
              ),
            ),
          ),
        ],

        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(
            title: 'Historial de ciclos',
            icon: Icons.history_rounded,
            color: AppColors.phasePeriod,
            trailing: Text(
              '${history.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (var i = 0; i < history.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _HistoryTile(entry: history[i]),
              ),
            ),
        ],

        const SizedBox(height: AppSpacing.lg),
        PanelActionButton(
          label: 'Registrar periodo',
          icon: Icons.water_drop_rounded,
          color: AppColors.phasePeriod,
          onPressed: () => showCycleSheet(context, dateStr: targetDay),
        ),
      ],
    );
  }
}

/// Tarjeta de la fase actual, con el consejo del día y la probabilidad de
/// embarazo.
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.details});

  final CycleDetails details;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final phase = details.phase;

    return AppCard(
      accent: phase.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(details.dateTitle, style: text.titleSmall),
              ),
              StatusPill(label: phase.label, color: phase.color),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Probabilidad de embarazo.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: phase.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border(
                left: BorderSide(color: phase.color, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.child_care_rounded, size: 17, color: phase.color),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Probabilidad de embarazo: ',
                  style: text.bodySmall?.copyWith(fontSize: 12),
                ),
                Text(
                  phase.fertilityChance,
                  style: text.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: phase.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            details.description,
            style: text.bodyMedium?.copyWith(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),

          ProgressBar(
            progress: details.progressPercent / 100,
            color: phase.color,
            height: 6,
          ),
        ],
      ),
    );
  }
}

class _NextPeriodCard extends StatelessWidget {
  const _NextPeriodCard({required this.details});

  final CycleDetails details;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final late = details.phase == CyclePhase.latePeriod;

    return AppCard(
      accent: late ? AppColors.phaseLate : AppColors.phasePeriod,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            late ? Icons.hourglass_bottom_rounded : Icons.water_drop_rounded,
            size: 24,
            color: late ? AppColors.phaseLate : AppColors.phasePeriod,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  late
                      ? 'Con ${details.diasRetraso} día${details.diasRetraso == 1 ? '' : 's'} de retraso'
                      : 'Próximo periodo en ${details.nextPeriodIn} día${details.nextPeriodIn == 1 ? '' : 's'}',
                  style: text.titleSmall?.copyWith(
                    color: late ? AppColors.phaseLate : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.esCicloObservado
                      ? 'Ciclo de referencia: ${details.actualCycleLength} días (observado).'
                      : 'Proyección sobre ${details.actualCycleLength} días, el promedio de tus ciclos recientes.',
                  style: text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry});

  final CycleHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final accent = entry.anomalo ? AppColors.warning : AppColors.phasePeriod;

    return AppCard(
      accent: accent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: () => showCycleSheet(
        context,
        dateStr: entry.fechaInicio,
        log: entry.log,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppDate.long(entry.fechaInicio),
                      style: text.titleSmall?.copyWith(fontSize: 13),
                    ),
                    if (entry.enCurso) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text('· en curso', style: text.bodySmall),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (entry.duracion == null)
                      'Duración pendiente'
                    else
                      'Ciclo de ${entry.duracion} días'
                          '${entry.anomalo ? ' ⚠ atípico' : ''}',
                    if (entry.diasSangrado != null)
                      'sangrado ${entry.diasSangrado} días'
                    else
                      'sangrado sin registrar',
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color:
                        entry.anomalo ? AppColors.warning : colors.textSecondary,
                  ),
                ),
                if (entry.observacion != null &&
                    entry.observacion!.isNotEmpty)
                  Text(
                    entry.observacion!,
                    style: text.bodySmall?.copyWith(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: colors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, size: 16, color: colors.textTertiary),
        ],
      ),
    );
  }
}

/// Duración estándar exportada para tests del panel.
const Duration kCyclePanelEntrance = AppMotion.standard;
