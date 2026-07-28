import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/finance.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/panel_parts.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../shell/dashboard_controller.dart';
import '../finance_sheets.dart';

/// Pestaña Metas de ahorro.
class GoalsTab extends StatelessWidget {
  const GoalsTab({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final goals = state.bootstrap.metas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelActionButton(
          label: 'Nueva meta de ahorro',
          icon: Icons.flag_rounded,
          color: AppColors.income,
          onPressed: () => showGoalSheet(context),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (goals.isEmpty)
          EmptyState(
            icon: Icons.flag_rounded,
            title: 'Sin metas todavía',
            message:
                'Define una meta —un viaje, un fondo de emergencia— y ve cómo se llena con cada aporte.',
            color: AppColors.income,
            actionLabel: 'Crear meta',
            onAction: () => showGoalSheet(context),
            compact: true,
          )
        else
          for (var i = 0; i < goals.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _GoalCard(goal: goals[i]),
              ),
            ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final daysLeft = goal.daysLeft;

    return AppCard(
      accent: goal.accentColor,
      onTap: () => showGoalSheet(context, goal: goal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: goal.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(goal.iconData, size: 20, color: goal.accentColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.nombre, style: text.titleSmall),
                    if (goal.completada)
                      const StatusPill(
                        label: '✅ Completada',
                        color: AppColors.income,
                      )
                    else if (daysLeft != null)
                      StatusPill(
                        label: daysLeft < 0
                            ? 'Venció hace ${daysLeft.abs()}d'
                            : '$daysLeft días restantes',
                        color: daysLeft < 0
                            ? AppColors.danger
                            : daysLeft <= 30
                                ? AppColors.warning
                                : colors.textSecondary,
                      ),
                  ],
                ),
              ),
              if (!goal.completada)
                IconButton(
                  onPressed: () =>
                      showGoalContributionSheet(context, goal: goal),
                  icon: const Icon(Icons.savings_rounded, size: 20),
                  color: AppColors.income,
                  tooltip: 'Registrar aporte',
                ),
            ],
          ),

          if (goal.descripcion != null && goal.descripcion!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              goal.descripcion!,
              style: text.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppCurrency.format(goal.montoActual),
                style: text.titleMedium?.copyWith(color: goal.accentColor),
              ),
              Text(
                ' / ${AppCurrency.format(goal.montoObjetivo)}',
                style: text.bodySmall,
              ),
              const Spacer(),
              Text(
                '${goal.progress.toStringAsFixed(0)}%',
                style: text.titleSmall?.copyWith(color: goal.accentColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ProgressBar(
            progress: goal.progress / 100,
            color: goal.accentColor,
          ),
        ],
      ),
    );
  }
}
