import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Formulario de cuenta (ahorros, efectivo, CDT, tarjeta de crédito…).
Future<void> showAccountSheet(BuildContext context, {Account? account}) {
  return showAppSheet(
    context,
    builder: (context) => _AccountSheet(account: account),
  );
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.account});

  final Account? account;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _limitController = TextEditingController();
  final _rateController = TextEditingController();
  final _termController = TextEditingController();

  AccountType _type = AccountType.savings;
  String _startDate = AppDate.today();
  int? _cutoffDay;
  bool _saving = false;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    if (account != null) {
      _nameController.text = account.nombre;
      _type = account.tipo;
      CurrencyField.setValue(_balanceController, account.saldo);
      CurrencyField.setValue(_limitController, account.limite);
      if (account.interesTasa > 0) {
        _rateController.text = account.interesTasa.toString();
      }
      if (account.plazoDias > 0) {
        _termController.text = account.plazoDias.toString();
      }
      _startDate = account.fechaInicio ?? AppDate.today();
      _cutoffDay = account.diaCorte;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveAccount(
            id: widget.account?.id,
            nombre: _nameController.text.trim(),
            tipo: _type,
            saldo: CurrencyField.valueOf(_balanceController),
            limite: CurrencyField.valueOf(_limitController),
            interesTasa:
                double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0,
            fechaInicio: _type == AccountType.cdt ? _startDate : null,
            plazoDias: int.tryParse(_termController.text) ?? 0,
            diaCorte: _type == AccountType.creditCard ? _cutoffDay : null,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        _isEdit ? 'Cuenta actualizada' : 'Cuenta creada',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCdt = _type == AccountType.cdt;
    final isCreditCard = _type == AccountType.creditCard;

    return AppSheetScaffold(
      title: _isEdit ? 'Editar cuenta' : 'Nueva cuenta',
      icon: _type.icon,
      accent: AppColors.gold,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: AppColors.gold,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Nombre',
              controller: _nameController,
              icon: Icons.badge_outlined,
              hint: 'Bancolombia ahorros',
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Ponle un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            PickerField<AccountType>(
              label: 'Tipo de cuenta',
              value: _type,
              accent: AppColors.gold,
              options: [
                for (final t in AccountType.values)
                  PickerOption(value: t, label: t.label, icon: t.icon),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: AppSpacing.lg),

            CurrencyField(
              controller: _balanceController,
              label: isCreditCard ? 'Deuda actual' : 'Saldo actual',
              accent:
                  isCreditCard ? AppColors.expense : AppColors.income,
            ),

            AnimatedSize(
              duration: AppMotion.scale(context, AppMotion.standard),
              alignment: Alignment.topCenter,
              child: isCreditCard
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CurrencyField(
                            controller: _limitController,
                            label: 'Cupo autorizado',
                            accent: AppColors.gold,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PickerField<int?>(
                            label: 'Día de corte',
                            value: _cutoffDay,
                            accent: AppColors.gold,
                            options: [
                              const PickerOption<int?>(
                                value: null,
                                label: 'Sin día de corte',
                                icon: Icons.block_rounded,
                              ),
                              for (var d = 1; d <= 28; d++)
                                PickerOption<int?>(
                                  value: d,
                                  label: 'Día $d de cada mes',
                                  icon: Icons.event_rounded,
                                ),
                            ],
                            onChanged: (v) => setState(() => _cutoffDay = v),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),

            AnimatedSize(
              duration: AppMotion.scale(context, AppMotion.standard),
              alignment: Alignment.topCenter,
              child: isCdt
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'Tasa E.A. (%)',
                            controller: _rateController,
                            icon: Icons.percent_rounded,
                            hint: '10.5',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            label: 'Plazo en días',
                            controller: _termController,
                            icon: Icons.schedule_rounded,
                            hint: '0 = rendimiento continuo (cajita)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            helperText:
                                'Con plazo, el CDT deja de capitalizar al vencer. Sin plazo, rinde de forma continua.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DateField(
                            label: 'Fecha de apertura',
                            value: _startDate,
                            onChanged: (v) => setState(() => _startDate = v),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),

            const SizedBox(height: AppSpacing.md),
            if (_isEdit)
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar cuenta'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar cuenta',
      message:
          'Se eliminará "${widget.account!.nombre}". Los movimientos asociados quedarán sin cuenta.',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .deleteAccount(widget.account!.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Cuenta eliminada');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }
}

/// Campo de fecha con el selector nativo.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: colors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: colors.bgTertiary,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: AppDate.parse(value),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(AppDate.toKey(picked));
            },
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18, color: colors.textTertiary),
                  const SizedBox(width: AppSpacing.md),
                  Text(AppDate.long(value), style: text.bodyLarge),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
