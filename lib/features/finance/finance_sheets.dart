import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/material_icon_map.dart';
import '../../data/models/finance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/currency_field.dart';
import '../../shared/widgets/date_field.dart';
import '../../shared/widgets/option_picker.dart';
import '../shell/dashboard_controller.dart';

// ---------------------------------------------------------------------------
// Transferencia entre cuentas
// ---------------------------------------------------------------------------

Future<void> showTransferSheet(BuildContext context) {
  return showAppSheet(context, builder: (context) => const _TransferSheet());
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet();

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _fromId;
  int? _toId;
  String _date = AppDate.today();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts = ref.read(dashboardControllerProvider).bootstrap.cuentas;
    if (accounts.length >= 2) {
      _fromId = accounts[0].id;
      _toId = accounts[1].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = CurrencyField.valueOf(_amountController);
    if (_fromId == null || _toId == null || amount <= 0) {
      AppFeedback.showError(context, 'Completa origen, destino y monto.');
      return;
    }
    if (_fromId == _toId) {
      AppFeedback.showError(
          context, 'Las cuentas de origen y destino deben ser diferentes.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).createTransfer(
            cuentaOrigenId: _fromId!,
            cuentaDestinoId: _toId!,
            monto: amount,
            fecha: _date,
            descripcion: _descriptionController.text.trim(),
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Transferencia registrada');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(dashboardControllerProvider).bootstrap.cuentas;

    List<PickerOption<int?>> optionsFor() => [
          for (final a in accounts)
            PickerOption<int?>(
              value: a.id,
              label: a.nombre,
              subtitle:
                  '${a.tipo.label} · ${AppCurrency.format(a.saldo)}',
              icon: a.tipo.icon,
              color: a.color,
            ),
        ];

    return AppSheetScaffold(
      title: 'Transferir entre cuentas',
      icon: Icons.swap_horiz_rounded,
      accent: AppColors.sky,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.sky,
        confirmLabel: 'Transferir',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField<int?>(
            label: 'Desde',
            value: _fromId,
            accent: AppColors.expense,
            options: optionsFor(),
            onChanged: (v) => setState(() => _fromId = v),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Flecha que apunta el sentido del dinero.
          Center(
            child: Icon(
              Icons.arrow_downward_rounded,
              color: AppColors.sky.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          PickerField<int?>(
            label: 'Hacia',
            value: _toId,
            accent: AppColors.income,
            options: optionsFor(),
            onChanged: (v) => setState(() => _toId = v),
          ),
          const SizedBox(height: AppSpacing.lg),

          CurrencyField(
            controller: _amountController,
            label: 'Monto',
            accent: AppColors.sky,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.lg),

          AppTextField(
            label: 'Descripción',
            controller: _descriptionController,
            icon: Icons.notes_rounded,
            hint: 'Opcional',
            maxLength: 255,
          ),
          const SizedBox(height: AppSpacing.lg),

          DateField(
            label: 'Fecha',
            value: _date,
            onChanged: (v) => setState(() => _date = v),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meta de ahorro
// ---------------------------------------------------------------------------

Future<void> showGoalSheet(BuildContext context, {SavingsGoal? goal}) {
  return showAppSheet(context, builder: (context) => _GoalSheet(goal: goal));
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();

  String? _targetDate;
  String _icon = 'savings';
  Color _color = const Color(0xFF34E47E);
  bool _saving = false;

  static const _palette = [
    Color(0xFF34E47E), Color(0xFF4FC3F7), Color(0xFFFFD700), Color(0xFFFF7043),
    Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFF26A69A), Color(0xFF8D6E63),
  ];

  bool get _isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _nameController.text = goal.nombre;
      _descriptionController.text = goal.descripcion ?? '';
      CurrencyField.setValue(_targetController, goal.montoObjetivo);
      CurrencyField.setValue(_currentController, goal.montoActual);
      _targetDate = goal.fechaObjetivo;
      _icon = goal.icono;
      _color = goal.accentColor;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final target = CurrencyField.valueOf(_targetController);
    final current = CurrencyField.valueOf(_currentController);

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveGoal(
            id: widget.goal?.id,
            nombre: _nameController.text.trim(),
            descripcion: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            montoObjetivo: target,
            montoActual: current,
            fechaObjetivo: _targetDate,
            icono: _icon,
            color: toHexColor(_color),
            completada: current >= target && target > 0,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
          context, _isEdit ? 'Meta actualizada' : 'Meta creada');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  Future<void> _delete() async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar meta',
      message: '¿Eliminar "${widget.goal!.nombre}"?',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).deleteGoal(widget.goal!.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Meta eliminada');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: _isEdit ? 'Editar meta' : 'Nueva meta de ahorro',
      icon: MaterialIconMap.resolve(_icon),
      accent: _color,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: _color,
        onDelete: _isEdit ? _delete : null,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Nombre',
              controller: _nameController,
              icon: Icons.flag_rounded,
              hint: 'Viaje a San Andrés',
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Ponle un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            CurrencyField(
              controller: _targetController,
              label: 'Monto objetivo',
              accent: _color,
              validator: (v) => AppCurrency.parseInput(v ?? '') <= 0
                  ? 'Define el objetivo'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            CurrencyField(
              controller: _currentController,
              label: 'Ahorrado hasta hoy',
              accent: _color,
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DateField(
                    label: 'Fecha límite',
                    value: _targetDate ?? AppDate.today(),
                    onChanged: (v) => setState(() => _targetDate = v),
                  ),
                ),
                if (_targetDate != null)
                  IconButton(
                    onPressed: () => setState(() => _targetDate = null),
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    tooltip: 'Sin fecha límite',
                  ),
              ],
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
              colors: _palette,
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: 'Descripción',
              controller: _descriptionController,
              hint: 'Opcional',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aporte rápido a una meta
// ---------------------------------------------------------------------------

Future<void> showGoalContributionSheet(
  BuildContext context, {
  required SavingsGoal goal,
}) {
  return showAppSheet(
    context,
    builder: (context) => _ContributionSheet(goal: goal),
  );
}

class _ContributionSheet extends ConsumerStatefulWidget {
  const _ContributionSheet({required this.goal});

  final SavingsGoal goal;

  @override
  ConsumerState<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<_ContributionSheet> {
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = CurrencyField.valueOf(_amountController);
    if (amount <= 0) {
      AppFeedback.showError(context, 'Escribe cuánto vas a aportar.');
      return;
    }

    final goal = widget.goal;
    final newTotal = goal.montoActual + amount;
    final completed = newTotal >= goal.montoObjetivo;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveGoal(
            id: goal.id,
            nombre: goal.nombre,
            descripcion: goal.descripcion,
            montoObjetivo: goal.montoObjetivo,
            montoActual: newTotal,
            fechaObjetivo: goal.fechaObjetivo,
            icono: goal.icono,
            color: goal.color,
            completada: completed,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        completed
            ? '🎉 ¡Meta "${goal.nombre}" completada!'
            : 'Aporte registrado',
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
    final goal = widget.goal;

    return AppSheetScaffold(
      title: 'Aporte a "${goal.nombre}"',
      icon: goal.iconData,
      accent: goal.accentColor,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: goal.accentColor,
        confirmLabel: 'Aportar',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Llevas ${AppCurrency.format(goal.montoActual)} de '
            '${AppCurrency.format(goal.montoObjetivo)} '
            '(faltan ${AppCurrency.format(goal.remaining)}).',
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          CurrencyField(
            controller: _amountController,
            label: 'Cuánto aportas hoy',
            accent: goal.accentColor,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Presupuesto mensual por categoría
// ---------------------------------------------------------------------------

Future<void> showBudgetSheet(
  BuildContext context, {
  required String categoria,
  required String categoriaLabel,
  required int mes,
  required int anio,
  double? currentLimit,
  int? budgetId,
}) {
  return showAppSheet(
    context,
    builder: (context) => _BudgetSheet(
      categoria: categoria,
      categoriaLabel: categoriaLabel,
      mes: mes,
      anio: anio,
      currentLimit: currentLimit,
      budgetId: budgetId,
    ),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({
    required this.categoria,
    required this.categoriaLabel,
    required this.mes,
    required this.anio,
    this.currentLimit,
    this.budgetId,
  });

  final String categoria;
  final String categoriaLabel;
  final int mes;
  final int anio;
  final double? currentLimit;
  final int? budgetId;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _limitController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentLimit != null && widget.currentLimit! > 0) {
      CurrencyField.setValue(_limitController, widget.currentLimit!);
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final limit = CurrencyField.valueOf(_limitController);
    if (limit <= 0) {
      AppFeedback.showError(context, 'Define un límite mayor a cero.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveBudget(
            categoria: widget.categoria,
            montoLimite: limit,
            mes: widget.mes,
            anio: widget.anio,
          );
      await ref.read(dashboardControllerProvider.notifier).refreshMonth();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Presupuesto guardado');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .deleteBudget(widget.budgetId!);
      await ref.read(dashboardControllerProvider.notifier).refreshMonth();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Presupuesto eliminado');
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
      title: 'Presupuesto de ${widget.categoriaLabel}',
      subtitle: AppDate.monthLabel(widget.anio, widget.mes),
      icon: Icons.pie_chart_rounded,
      accent: AppColors.warning,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.warning,
        onDelete: widget.budgetId == null ? null : _delete,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Define cuánto quieres gastar como máximo en esta categoría durante el mes. '
            'La tarjeta se llenará a medida que registres gastos.',
            style: text.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          CurrencyField(
            controller: _limitController,
            label: 'Límite mensual',
            accent: AppColors.warning,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ingreso planificado
// ---------------------------------------------------------------------------

Future<void> showPlannedIncomeSheet(BuildContext context) {
  return showAppSheet(
    context,
    builder: (context) => const _PlannedIncomeSheet(),
  );
}

class _PlannedIncomeSheet extends ConsumerStatefulWidget {
  const _PlannedIncomeSheet();

  @override
  ConsumerState<_PlannedIncomeSheet> createState() =>
      _PlannedIncomeSheetState();
}

class _PlannedIncomeSheetState extends ConsumerState<_PlannedIncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  int? _accountId;
  String _frequency = 'mensual';
  String _startDate = AppDate.today();
  bool _saving = false;

  static const _frequencies = [
    ('diario', 'Diario'),
    ('semanal', 'Semanal'),
    ('quincenal', 'Quincenal'),
    ('mensual', 'Mensual'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).createPlannedIncome(
            descripcion: _descriptionController.text.trim(),
            monto: CurrencyField.valueOf(_amountController),
            frecuencia: _frequency,
            fechaInicio: _startDate,
            cuentaId: _accountId,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Ingreso planificado');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(dashboardControllerProvider).bootstrap.cuentas;

    return AppSheetScaffold(
      title: 'Ingreso recurrente',
      icon: Icons.date_range_rounded,
      accent: AppColors.income,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.income,
        confirmLabel: 'Planificar',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Descripción',
              controller: _descriptionController,
              icon: Icons.notes_rounded,
              hint: 'Salario, arriendo que te pagan…',
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Descríbelo' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            CurrencyField(
              controller: _amountController,
              label: 'Monto esperado',
              accent: AppColors.income,
              validator: (v) => AppCurrency.parseInput(v ?? '') <= 0
                  ? 'Escribe el monto'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            PickerField<String>(
              label: 'Frecuencia',
              value: _frequency,
              accent: AppColors.income,
              options: [
                for (final (value, label) in _frequencies)
                  PickerOption(
                    value: value,
                    label: label,
                    icon: Icons.repeat_rounded,
                  ),
              ],
              onChanged: (v) => setState(() => _frequency = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            DateField(
              label: 'Primera fecha esperada',
              value: _startDate,
              onChanged: (v) => setState(() => _startDate = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (accounts.isNotEmpty)
              PickerField<int?>(
                label: 'Cuenta destino',
                value: _accountId,
                accent: AppColors.income,
                options: [
                  const PickerOption<int?>(
                    value: null,
                    label: 'Sin cuenta',
                    icon: Icons.block_rounded,
                  ),
                  for (final a in accounts)
                    PickerOption<int?>(
                      value: a.id,
                      label: a.nombre,
                      subtitle: a.tipo.label,
                      icon: a.tipo.icon,
                      color: a.color,
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verificar la llegada de un ingreso planificado
// ---------------------------------------------------------------------------

Future<void> showVerifyIncomeSheet(
  BuildContext context, {
  required PlannedOccurrence occurrence,
}) {
  return showAppSheet(
    context,
    builder: (context) => _VerifyIncomeSheet(occurrence: occurrence),
  );
}

class _VerifyIncomeSheet extends ConsumerStatefulWidget {
  const _VerifyIncomeSheet({required this.occurrence});

  final PlannedOccurrence occurrence;

  @override
  ConsumerState<_VerifyIncomeSheet> createState() => _VerifyIncomeSheetState();
}

class _VerifyIncomeSheetState extends ConsumerState<_VerifyIncomeSheet> {
  final _amountController = TextEditingController();

  late String _realDate = AppDate.today();
  int? _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    CurrencyField.setValue(_amountController, widget.occurrence.plan.monto);
    _accountId = widget.occurrence.plan.cuentaId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = CurrencyField.valueOf(_amountController);
    if (amount <= 0) {
      AppFeedback.showError(context, 'Escribe cuánto recibiste.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).verifyPlannedIncome(
            planId: widget.occurrence.plan.id,
            fechaEsperada: widget.occurrence.fechaEsperada,
            fechaReal: _realDate,
            montoReal: amount,
            cuentaId: _accountId,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Ingreso verificado ✔');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accounts =
        ref.watch(dashboardControllerProvider).bootstrap.cuentas;
    final occurrence = widget.occurrence;

    return AppSheetScaffold(
      title: 'Verificar ingreso',
      subtitle: occurrence.descripcion,
      icon: Icons.task_alt_rounded,
      accent: AppColors.income,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.income,
        confirmLabel: 'Confirmar',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Se esperaba ${AppCurrency.format(occurrence.plan.monto)} el '
            '${AppDate.long(occurrence.fechaEsperada)}. Confirma cuánto llegó '
            'realmente y cuándo.',
            style: text.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          CurrencyField(
            controller: _amountController,
            label: 'Monto real recibido',
            accent: AppColors.income,
          ),
          const SizedBox(height: AppSpacing.lg),
          DateField(
            label: 'Fecha real',
            value: _realDate,
            onChanged: (v) => setState(() => _realDate = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (accounts.isNotEmpty)
            PickerField<int?>(
              label: 'Cuenta que lo recibió',
              value: _accountId,
              accent: AppColors.income,
              options: [
                const PickerOption<int?>(
                  value: null,
                  label: 'Sin cuenta',
                  icon: Icons.block_rounded,
                ),
                for (final a in accounts)
                  PickerOption<int?>(
                    value: a.id,
                    label: a.nombre,
                    subtitle: a.tipo.label,
                    icon: a.tipo.icon,
                    color: a.color,
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nueva categoría de finanzas
// ---------------------------------------------------------------------------

Future<void> showCategorySheet(BuildContext context) {
  return showAppSheet(context, builder: (context) => const _CategorySheet());
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet();

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _labelController = TextEditingController();
  String _icon = 'sell';
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      AppFeedback.showError(context, 'Escribe el nombre de la categoría.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .createCategory(label: label, icono: _icon);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Categoría creada');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: 'Nueva categoría',
      icon: MaterialIconMap.resolve(_icon),
      accent: AppColors.gold,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.gold,
        confirmLabel: 'Crear',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Nombre',
            controller: _labelController,
            icon: Icons.sell_rounded,
            hint: 'Mascotas, Streaming…',
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          PickerField<String>(
            label: 'Icono',
            value: _icon,
            searchable: true,
            accent: AppColors.gold,
            options: [
              for (final option in MaterialIconMap.picker)
                PickerOption(
                  value: option.value,
                  label: option.label,
                  icon: MaterialIconMap.resolve(option.value),
                ),
            ],
            onChanged: (v) => setState(() => _icon = v),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
