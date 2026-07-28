import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/habit.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/panel_parts.dart';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/skeleton.dart';
import '../shell/dashboard_controller.dart';
import 'habit_check.dart';
import 'habit_sheet.dart';

/// Panel del módulo Hábitos.
class HabitsPanel extends ConsumerWidget {
  const HabitsPanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final habits = state.bootstrap.habits;

    // El día que se marca: el seleccionado, u hoy.
    final targetDay = state.selectedDay ?? AppDate.today();
    final dayLogs = state.monthData.habitLogs
        .where((l) => l.fecha == targetDay && l.completado)
        .map((l) => l.habitoId)
        .toSet();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        HintBar(text: AppModule.habits.hint, icon: Icons.self_improvement_rounded),
        const SizedBox(height: AppSpacing.lg),

        if (state.selectedDay != null) ...[
          SelectedDayHeader(
            dateStr: state.selectedDay!,
            subtitle: 'Progreso de hábitos',
            icon: Icons.self_improvement_rounded,
            onClear: controller.clearSelection,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (state.loading)
          const ListSkeleton(count: 3)
        else if (habits.isEmpty)
          EmptyState(
            icon: Icons.self_improvement_rounded,
            title: 'Construye tu primera rutina',
            message:
                'Crea hábitos y márcalos cada día. La constancia se vuelve visible en el calendario.',
            actionLabel: 'Crear hábito',
            onAction: () => showHabitSheet(context),
            compact: true,
          )
        else ...[
          // Anillo de progreso del día.
          FadeSlideIn(
            child: _DaySummary(
              done: dayLogs.length,
              total: habits.length,
              dateStr: targetDay,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          for (var i = 0; i < habits.length; i++)
            FadeSlideIn(
              index: i + 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _HabitCard(
                  habit: habits[i],
                  checked: dayLogs.contains(habits[i].id),
                  dateStr: targetDay,
                  logs: state.monthData.habitLogs,
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.sm),
          PanelActionButton(
            label: 'Nuevo hábito',
            icon: Icons.add_task_rounded,
            onPressed: () => showHabitSheet(context),
          ),
        ],
      ],
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.done,
    required this.total,
    required this.dateStr,
  });

  final int done;
  final int total;
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final progress = total == 0 ? 0.0 : done / total;
    final complete = done == total && total > 0;
    final relative = AppDate.relativeLabel(dateStr);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          ProgressRing(
            progress: progress,
            size: 62,
            strokeWidth: 7,
            color: complete ? AppColors.gold : colors.accent,
            child: Text(
              '$done/$total',
              style: text.titleSmall?.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete
                      ? '¡Día completo! 🎉'
                      : relative == null
                          ? AppDate.medium(dateStr)
                          : '$relative, ${done == 0 ? "aún sin marcar" : "vas bien"}',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  complete
                      ? 'Todos tus hábitos cumplidos.'
                      : 'Toca el círculo de cada hábito para marcarlo.',
                  style: text.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends ConsumerStatefulWidget {
  const _HabitCard({
    required this.habit,
    required this.checked,
    required this.dateStr,
    required this.logs,
  });

  final Habit habit;
  final bool checked;
  final String dateStr;
  final List<HabitLog> logs;

  @override
  ConsumerState<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<_HabitCard> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    value ? AppFeedback.success() : AppFeedback.select();

    try {
      await ref.read(wellnessRepositoryProvider).logHabit(
            habitId: widget.habit.id,
            fecha: widget.dateStr,
            completado: value,
          );
      await ref.read(dashboardControllerProvider.notifier).refreshMonth();
    } on ApiException catch (e) {
      if (mounted) AppFeedback.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final habit = widget.habit;
    final streak = calculateStreak(habit.id, widget.logs);

    return AppCard(
      accent: habit.accentColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: () => showHabitSheet(context, habit: habit),
      child: Row(
        children: [
          HabitCheck(
            checked: widget.checked,
            color: habit.accentColor,
            onChanged: _toggle,
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(habit.iconData, size: 20, color: habit.accentColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.nombre,
                  style: text.titleSmall?.copyWith(
                    decoration:
                        widget.checked ? TextDecoration.lineThrough : null,
                    color: widget.checked
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  habit.frecuencia,
                  style: text.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          _StreakBadge(streak: streak),
        ],
      ),
    );
  }
}

/// Racha con llama. A partir de 7 días la llama se enciende en dorado.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final hot = streak >= 7;
    final color = hot ? AppColors.gold : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: streak == 0 ? 0.06 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: streak == 0 ? color.withValues(alpha: 0.4) : color,
          ),
          const SizedBox(width: 3),
          Text(
            '${streak}d',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: streak == 0 ? color.withValues(alpha: 0.5) : color,
            ),
          ),
        ],
      ),
    );
  }
}
