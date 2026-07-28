import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/cycle/cycle_engine.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/cycle.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_text_field.dart';
import '../shell/dashboard_controller.dart';

/// Registro del día 1 de un ciclo.
Future<void> showCycleSheet(
  BuildContext context, {
  required String dateStr,
  CycleLog? log,
}) {
  return showAppSheet(
    context,
    builder: (context) => _CycleSheet(dateStr: dateStr, log: log),
  );
}

class _CycleSheet extends ConsumerStatefulWidget {
  const _CycleSheet({required this.dateStr, this.log});

  final String dateStr;
  final CycleLog? log;

  @override
  ConsumerState<_CycleSheet> createState() => _CycleSheetState();
}

class _CycleSheetState extends ConsumerState<_CycleSheet> {
  final _observationController = TextEditingController();

  /// null = "no lo sé todavía", que es distinto de 0.
  int? _bleedingDays;

  bool _saving = false;

  bool get _isEdit => widget.log?.id != null;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    if (log != null) {
      _observationController.text = log.observacion ?? '';
      _bleedingDays = CycleEngine.sangradoRegistrado(log.diasSangrado);
    } else {
      // Se precarga el promedio de la usuaria: casi siempre acierta y ahorra
      // un paso al registrar.
      final stats = CycleEngine.buildStats(
        ref.read(dashboardControllerProvider).bootstrap.cycles,
      );
      if (stats.sangradosUsados > 0) _bleedingDays = stats.avgPeriodLength;
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(wellnessRepositoryProvider).saveCycle(
            id: widget.log?.id,
            fechaInicio: widget.dateStr,
            observacion: _observationController.text.trim(),
            diasSangrado: _bleedingDays,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        _isEdit ? 'Ciclo actualizado' : 'Periodo registrado',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  Future<void> _delete() async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar registro',
      message:
          'Al borrarlo, el calendario recalcula todas las fases desde el registro anterior.',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(wellnessRepositoryProvider).deleteCycle(widget.log!.id!);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Registro eliminado');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return AppSheetScaffold(
      title: _isEdit ? 'Editar ciclo' : 'Registrar periodo',
      subtitle: AppDate.weekdayLong(widget.dateStr),
      icon: Icons.water_drop_rounded,
      accent: AppColors.phasePeriod,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.phasePeriod,
        onDelete: _isEdit ? _delete : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.phasePeriod.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: AppColors.phasePeriod.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.phasePeriod),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Esta fecha se guarda como el día 1 del ciclo. '
                    'Todas las fases se recalculan a partir de aquí.',
                    style: text.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            'DÍAS DE SANGRADO',
            style: text.labelSmall?.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _bleedingDays == null
                ? 'Sin registrar: se usará tu promedio para calcular la fase.'
                : 'La menstruación se pintará durante $_bleedingDays día(s).',
            style: text.bodySmall?.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: AppSpacing.md),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _DayChip(
                label: 'No lo sé',
                selected: _bleedingDays == null,
                onTap: () => setState(() => _bleedingDays = null),
              ),
              for (var d = CycleEngine.minSangrado;
                  d <= 10;
                  d++)
                _DayChip(
                  label: '$d',
                  selected: _bleedingDays == d,
                  onTap: () => setState(() => _bleedingDays = d),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          AppTextField(
            label: 'Observaciones',
            controller: _observationController,
            hint: 'Cólicos, flujo, ánimo…',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: selected
          ? AppColors.phasePeriod.withValues(alpha: 0.16)
          : colors.bgTertiary,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selected ? AppColors.phasePeriod : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.phasePeriod : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
