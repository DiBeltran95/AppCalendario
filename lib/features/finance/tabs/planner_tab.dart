import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/finance.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/panel_parts.dart';
import '../../shell/dashboard_controller.dart';
import '../finance_sheets.dart';

/// Pestaña Planificador: ingresos recurrentes y su verificación, como una
/// línea de tiempo vertical del mes.
class PlannerTab extends ConsumerWidget {
  const PlannerTab({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.selectedDay;
    final occurrences = selected == null
        ? state.occurrences
        : state.occurrences
            .where((o) => o.fechaEsperada == selected)
            .toList();
    final plans = state.bootstrap.ingresosPlanificados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelActionButton(
          label: 'Planificar ingreso recurrente',
          icon: Icons.date_range_rounded,
          color: AppColors.income,
          onPressed: () => showPlannedIncomeSheet(context),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (occurrences.isEmpty)
          EmptyState(
            icon: Icons.schedule_rounded,
            title: selected == null
                ? 'Nada planificado este mes'
                : 'Nada planeado para este día',
            message:
                'Planifica tus ingresos fijos (salario, arriendos) y verifícalos cuando lleguen.',
            color: AppColors.income,
            compact: true,
          )
        else ...[
          SectionTitle(
            title: selected == null
                ? 'Ocurrencias del mes'
                : 'Planeado para este día',
            icon: Icons.timeline_rounded,
            color: AppColors.income,
            trailing: Text(
              '${occurrences.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          // Línea de tiempo vertical.
          for (var i = 0; i < occurrences.length; i++)
            FadeSlideIn(
              index: i,
              child: _TimelineTile(
                occurrence: occurrences[i],
                isLast: i == occurrences.length - 1,
              ),
            ),
        ],

        if (plans.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(
            title: 'Planes activos',
            icon: Icons.repeat_rounded,
            color: AppColors.income,
          ),
          for (final plan in plans.where((p) => p.activo))
            _PlanTile(plan: plan),
        ],
      ],
    );
  }
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({required this.occurrence, required this.isLast});

  final PlannedOccurrence occurrence;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final color = occurrence.verificado
        ? AppColors.income
        : occurrence.isOverdue
            ? AppColors.danger
            : AppColors.warning;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Columna de la línea con el nodo.
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: AppSpacing.lg),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: occurrence.verificado ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: occurrence.verificado
                      ? const Icon(Icons.check_rounded,
                          size: 9, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: colors.divider,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.bgTertiary,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(occurrence.descripcion,
                              style: text.titleSmall?.copyWith(fontSize: 13)),
                        ),
                        Text(
                          AppCurrency.format(occurrence.monto),
                          style: text.titleSmall?.copyWith(color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      occurrence.verificado
                          ? '✔ Recibido el ${AppDate.medium(occurrence.verification!.fechaReal)}'
                          : occurrence.isOverdue
                              ? 'Esperado el ${AppDate.medium(occurrence.fechaEsperada)} — atrasado'
                              : 'Esperado el ${AppDate.medium(occurrence.fechaEsperada)} (${occurrence.plan.frecuencia})',
                      style: text.bodySmall?.copyWith(
                        fontSize: 11,
                        color: occurrence.isOverdue && !occurrence.verificado
                            ? AppColors.danger
                            : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: occurrence.verificado
                          ? TextButton(
                              onPressed: () => _undo(context, ref),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.textSecondary,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Deshacer'),
                            )
                          : FilledButton(
                              onPressed: () => showVerifyIncomeSheet(
                                context,
                                occurrence: occurrence,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                textStyle: const TextStyle(fontSize: 12.5),
                              ),
                              child: const Text('Verificar'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .undoVerification(occurrence.verification!.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Verificación deshecha');
      }
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
    }
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan});

  final PlannedIncome plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.bgTertiary,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.repeat_rounded,
                size: 16, color: AppColors.income),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '${plan.descripcion} · ${plan.frecuencia}',
                style: text.bodySmall?.copyWith(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              AppCurrency.format(plan.monto),
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.income,
              ),
            ),
            IconButton(
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              color: AppColors.danger,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar plan',
      message:
          'Se dejará de esperar "${plan.descripcion}". Las verificaciones pasadas se conservan.',
    );
    if (!ok) return;

    try {
      await ref.read(financeRepositoryProvider).deletePlannedIncome(plan.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (context.mounted) AppFeedback.showSuccess(context, 'Plan eliminado');
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
    }
  }
}
