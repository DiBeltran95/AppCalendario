import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/finance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/currency_field.dart';
import '../../shared/widgets/option_picker.dart';
import '../shell/dashboard_controller.dart';

/// Formulario de gasto o ingreso.
Future<void> showTransactionSheet(
  BuildContext context, {
  required String dateStr,
  bool isIncome = false,
  FinanceTransaction? transaction,
}) {
  return showAppSheet(
    context,
    builder: (context) => _TransactionSheet(
      dateStr: dateStr,
      isIncome: isIncome,
      transaction: transaction,
    ),
  );
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({
    required this.dateStr,
    required this.isIncome,
    this.transaction,
  });

  final String dateStr;
  final bool isIncome;
  final FinanceTransaction? transaction;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late bool _isIncome = widget.isIncome;
  int? _accountId;
  String _category = 'otros';
  int _installments = 1;
  bool _saving = false;

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _isIncome = tx.isIncome;
      CurrencyField.setValue(_amountController, tx.monto);
      _descriptionController.text = tx.descripcion;
      _accountId = tx.cuentaId;
      _category = tx.categoria;
      _installments = tx.cuotas;
    } else {
      // Cuenta por defecto: la primera que no sea tarjeta de crédito.
      final accounts = ref.read(dashboardControllerProvider).bootstrap.cuentas;
      if (accounts.isNotEmpty) {
        final preferred = accounts.firstWhere(
          (a) => a.tipo != AccountType.creditCard,
          orElse: () => accounts.first,
        );
        _accountId = preferred.id;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color get _accent => _isIncome ? AppColors.income : AppColors.expense;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveTransaction(
            id: widget.transaction?.id,
            tipo: _isIncome ? 'ingreso' : 'gasto',
            monto: CurrencyField.valueOf(_amountController),
            descripcion: _descriptionController.text.trim(),
            fecha: widget.dateStr,
            cuentaId: _accountId,
            categoria: _category,
            cuotas: _installments,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        _isEdit ? 'Movimiento actualizado' : 'Movimiento registrado',
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
      title: 'Eliminar movimiento',
      message:
          'Se revertirá el saldo de la cuenta asociada. Esta acción no se puede deshacer.',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .deleteTransaction(widget.transaction!.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Movimiento eliminado');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final accounts = state.bootstrap.cuentas;
    final categories = state.bootstrap.categorias;

    final selectedAccount = accounts.where((a) => a.id == _accountId).firstOrNull;
    final isCreditCard = selectedAccount?.isCreditCard ?? false;

    return AppSheetScaffold(
      title: _isEdit
          ? 'Editar movimiento'
          : (_isIncome ? 'Nuevo ingreso' : 'Nuevo gasto'),
      subtitle: AppDate.weekdayLong(widget.dateStr),
      icon: _isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      accent: _accent,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: _accent,
        onDelete: _isEdit ? _delete : null,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Conmutador gasto / ingreso.
            _TypeToggle(
              isIncome: _isIncome,
              onChanged: (v) => setState(() => _isIncome = v),
            ),
            const SizedBox(height: AppSpacing.xl),

            CurrencyField(
              controller: _amountController,
              label: 'Monto',
              accent: _accent,
              autofocus: !_isEdit,
              validator: (v) => AppCurrency.parseInput(v ?? '') <= 0
                  ? 'Escribe un monto'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: 'Descripción',
              controller: _descriptionController,
              icon: Icons.notes_rounded,
              hint: _isIncome ? 'Pago de nómina' : 'Mercado del mes',
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Escribe una descripción'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            if (accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Aún no tienes cuentas. El movimiento se guardará sin asociar a ninguna.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              PickerField<int?>(
                label: 'Cuenta',
                value: _accountId,
                accent: _accent,
                options: [
                  const PickerOption<int?>(
                    value: null,
                    label: 'Sin cuenta',
                    icon: Icons.block_rounded,
                  ),
                  for (final account in accounts)
                    PickerOption<int?>(
                      value: account.id,
                      label: account.nombre,
                      subtitle: account.tipo.label,
                      icon: account.tipo.icon,
                      color: account.color,
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            const SizedBox(height: AppSpacing.lg),

            PickerField<String>(
              label: 'Categoría',
              value: _category,
              searchable: true,
              accent: _accent,
              options: [
                for (var i = 0; i < categories.length; i++)
                  PickerOption(
                    value: categories[i].valor,
                    label: categories[i].label,
                    icon: categories[i].iconData,
                    color: FinanceCategory.colorFor(
                      categories[i].valor,
                      fallbackIndex: i,
                    ),
                  ),
                if (categories.isEmpty)
                  const PickerOption(
                    value: 'otros',
                    label: 'Otros',
                    icon: Icons.payments_rounded,
                  ),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),

            // Las cuotas solo tienen sentido en una tarjeta de crédito.
            AnimatedSize(
              duration: AppMotion.scale(context, AppMotion.standard),
              alignment: Alignment.topCenter,
              child: isCreditCard && !_isIncome
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: PickerField<int>(
                        label: 'Cuotas',
                        value: _installments,
                        accent: _accent,
                        options: [
                          for (final n in const [1, 2, 3, 6, 9, 12, 18, 24, 36])
                            PickerOption(
                              value: n,
                              label: n == 1 ? 'Una sola cuota' : '$n cuotas',
                              icon: Icons.credit_card_rounded,
                            ),
                        ],
                        onChanged: (v) => setState(() => _installments = v),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Conmutador entre gasto e ingreso, con la píldora deslizándose.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.isIncome, required this.onChanged});

  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppMotion.scale(context, AppMotion.standard),
            curve: AppMotion.emphasizedCurve,
            alignment: isIncome ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.income : AppColors.expense)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ToggleHalf(
                  label: 'Gasto',
                  icon: Icons.trending_down_rounded,
                  active: !isIncome,
                  color: AppColors.expense,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _ToggleHalf(
                  label: 'Ingreso',
                  icon: Icons.trending_up_rounded,
                  active: isIncome,
                  color: AppColors.income,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  const _ToggleHalf({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () {
        AppFeedback.select();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: active ? color : colors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          AnimatedDefaultTextStyle(
            duration: AppMotion.scale(context, AppMotion.quick),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? color : colors.textTertiary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
