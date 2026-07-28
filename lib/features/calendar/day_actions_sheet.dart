import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_sheet.dart';
import '../agenda/event_sheet.dart';
import '../cycle/cycle_sheet.dart';
import '../finance/transaction_sheet.dart';
import '../habits/habit_sheet.dart';
import '../notes/note_sheet.dart';
import '../shell/dashboard_controller.dart';

/// Menú de acciones rápidas de un día.
///
/// Sustituye al doble clic de la versión web: mantener pulsado abre esto, que
/// además deja crear cualquier cosa desde cualquier módulo sin cambiar de
/// pestaña primero.
Future<void> showDayActions(
  BuildContext context,
  WidgetRef ref,
  String dateStr,
) {
  final module = ref.read(activeModuleProvider);

  return showAppSheet(
    context,
    builder: (sheetContext) => AppSheetScaffold(
      title: 'Añadir a este día',
      subtitle: AppDate.weekdayLong(dateStr),
      icon: Icons.add_circle_outline_rounded,
      child: Column(
        children: [
          for (var i = 0; i < _actionsFor(module).length; i++)
            FadeSlideIn(
              index: i,
              offset: 10,
              child: _ActionTile(
                action: _actionsFor(module)[i],
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _actionsFor(module)[i].open(context, dateStr);
                },
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// El módulo activo decide el orden: lo más probable, primero.
List<_DayAction> _actionsFor(AppModule module) {
  const event = _DayAction(
    label: 'Evento',
    description: 'Reunión, cita, recordatorio',
    icon: Icons.event_rounded,
    color: Color(0xFF25D366),
    kind: _ActionKind.event,
  );
  const expense = _DayAction(
    label: 'Gasto',
    description: 'Registrar una salida de dinero',
    icon: Icons.trending_down_rounded,
    color: AppColors.expense,
    kind: _ActionKind.expense,
  );
  const income = _DayAction(
    label: 'Ingreso',
    description: 'Registrar una entrada de dinero',
    icon: Icons.trending_up_rounded,
    color: AppColors.income,
    kind: _ActionKind.income,
  );
  const note = _DayAction(
    label: 'Nota',
    description: 'Apunte rápido para este día',
    icon: Icons.edit_note_rounded,
    color: Color(0xFF4FC3F7),
    kind: _ActionKind.note,
  );
  const period = _DayAction(
    label: 'Inicio de periodo',
    description: 'Registrar el día 1 del ciclo',
    icon: Icons.water_drop_rounded,
    color: AppColors.phasePeriod,
    kind: _ActionKind.period,
  );
  const habit = _DayAction(
    label: 'Hábito',
    description: 'Crear un hábito nuevo',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFF4CAF50),
    kind: _ActionKind.habit,
  );

  return switch (module) {
    AppModule.agenda => const [event, expense, note],
    AppModule.finance => const [expense, income, event],
    AppModule.cycle => const [period, note, event],
    AppModule.notes => const [note, event, expense],
    AppModule.habits => const [habit, note, event],
  };
}

enum _ActionKind { event, expense, income, note, period, habit }

class _DayAction {
  const _DayAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.kind,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final _ActionKind kind;

  void open(BuildContext context, String dateStr) {
    switch (kind) {
      case _ActionKind.event:
        showEventSheet(context, dateStr: dateStr);
      case _ActionKind.expense:
        showTransactionSheet(context, dateStr: dateStr, isIncome: false);
      case _ActionKind.income:
        showTransactionSheet(context, dateStr: dateStr, isIncome: true);
      case _ActionKind.note:
        showNoteSheet(context, dateStr: dateStr);
      case _ActionKind.period:
        showCycleSheet(context, dateStr: dateStr);
      case _ActionKind.habit:
        showHabitSheet(context);
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});

  final _DayAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Icon(action.icon, size: 22, color: action.color),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.label, style: text.titleSmall),
                      Text(action.description, style: text.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
