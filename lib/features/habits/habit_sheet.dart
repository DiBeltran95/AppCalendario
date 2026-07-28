import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/material_icon_map.dart';
import '../../data/models/finance.dart' show parseHexColor, toHexColor;
import '../../data/models/habit.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/option_picker.dart';
import '../shell/dashboard_controller.dart';

/// Formulario de hábito.
Future<void> showHabitSheet(BuildContext context, {Habit? habit}) {
  return showAppSheet(
    context,
    builder: (context) => _HabitSheet(habit: habit),
  );
}

class _HabitSheet extends ConsumerStatefulWidget {
  const _HabitSheet({this.habit});

  final Habit? habit;

  @override
  ConsumerState<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends ConsumerState<_HabitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _icon = 'check_circle';
  Color _color = Habit.palette.first;
  String _frequency = 'diario';
  int _dailyGoal = 1;
  bool _saving = false;

  bool get _isEdit => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    if (habit != null) {
      _nameController.text = habit.nombre;
      _icon = habit.icono;
      _color = parseHexColor(habit.color, fallback: Habit.palette.first);
      _frequency = habit.frecuencia;
      _dailyGoal = habit.metaDiaria;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(wellnessRepositoryProvider).saveHabit(
            id: widget.habit?.id,
            nombre: _nameController.text.trim(),
            icono: _icon,
            color: toHexColor(_color),
            frecuencia: _frequency,
            metaDiaria: _dailyGoal,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        _isEdit ? 'Hábito actualizado' : 'Hábito creado',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppSheetScaffold(
      title: _isEdit ? 'Editar hábito' : 'Nuevo hábito',
      icon: MaterialIconMap.resolve(_icon),
      accent: _color,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: _color,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Nombre',
              controller: _nameController,
              hint: 'Beber 2 litros de agua',
              icon: Icons.title_rounded,
              autofocus: !_isEdit,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Ponle un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            PickerField<String>(
              label: 'Icono',
              value: _icon,
              searchable: true,
              accent: _color,
              options: [
                for (final option in MaterialIconMap.picker)
                  PickerOption(
                    value: option.value,
                    label: option.label,
                    icon: MaterialIconMap.resolve(option.value),
                    color: _color,
                  ),
              ],
              onChanged: (v) => setState(() => _icon = v),
            ),
            const SizedBox(height: AppSpacing.lg),

            ColorPickerRow(
              colors: Habit.palette,
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: AppSpacing.lg),

            PickerField<String>(
              label: 'Frecuencia',
              value: _frequency,
              accent: _color,
              options: [
                for (final f in Habit.frequencies)
                  PickerOption(
                    value: f.value,
                    label: f.label,
                    icon: Icons.repeat_rounded,
                    color: _color,
                  ),
              ],
              onChanged: (v) => setState(() => _frequency = v),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meta diaria', style: text.titleSmall),
                      Text(
                        'Cuántas veces al día cuenta como completo',
                        style: text.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _Stepper(
                  value: _dailyGoal,
                  color: _color,
                  onChanged: (v) => setState(() => _dailyGoal = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_isEdit)
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar hábito'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar hábito',
      message:
          'Se borrará "${widget.habit!.nombre}" y todo su historial de rachas.',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(wellnessRepositoryProvider).deleteHabit(widget.habit!.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Hábito eliminado');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }
}

/// Selector numérico compacto.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    required this.color,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: color),
            ),
          ),
          IconButton(
            onPressed: value < 20 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
