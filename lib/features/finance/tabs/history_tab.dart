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
import '../transaction_sheet.dart';

/// Pestaña Historial: movimientos del mes (o del día) agrupados por fecha,
/// más las transferencias del mes.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.selectedDay;
    final transactions = selected == null
        ? state.monthData.transacciones
        : state.selectedDayTransactions;
    final transfers = state.monthData.transferencias;
    final accountNames = {
      for (final a in state.bootstrap.cuentas) a.id: a.nombre,
    };

    // Agrupadas por fecha; el backend ya las manda de reciente a antigua.
    final grouped = <String, List<FinanceTransaction>>{};
    for (final t in transactions) {
      (grouped[t.fecha] ??= []).add(t);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    var itemIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelActionButton(
          label: selected == null
              ? 'Registrar movimiento'
              : 'Registrar movimiento este día',
          icon: Icons.add_rounded,
          color: AppColors.gold,
          onPressed: () => showTransactionSheet(
            context,
            dateStr: selected ?? AppDate.today(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (transactions.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Sin movimientos',
            message: selected == null
                ? 'No has registrado gastos ni ingresos este mes.'
                : 'No hay movimientos en este día.',
            color: AppColors.gold,
            compact: true,
          )
        else
          for (final date in dates) ...[
            _DateHeader(date: date, transactions: grouped[date]!),
            for (final tx in grouped[date]!)
              FadeSlideIn(
                index: itemIndex++,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TransactionTile(
                    transaction: tx,
                    accountName: accountNames[tx.cuentaId],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],

        if (selected == null && transfers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionTitle(
            title: 'Transferencias del mes',
            icon: Icons.swap_horiz_rounded,
            color: AppColors.sky,
            trailing: Text(
              '${transfers.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final transfer in transfers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TransferTile(
                transfer: transfer,
                accountNames: accountNames,
              ),
            ),
        ],
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.transactions});

  final String date;
  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final total =
        transactions.fold(0.0, (sum, t) => sum + t.signedAmount);
    final relative = AppDate.relativeLabel(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            relative ?? AppDate.weekdayLong(date),
            style: text.labelMedium?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Divider(color: colors.divider)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppCurrency.signed(total, isIncome: total >= 0),
            style: text.labelMedium?.copyWith(
              color: total >= 0 ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction, this.accountName});

  final FinanceTransaction transaction;
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tx = transaction;
    final color = tx.isIncome ? AppColors.income : AppColors.expense;

    // Deslizar para eliminar, con confirmación.
    return Dismissible(
      key: ValueKey('tx-${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      confirmDismiss: (_) => AppFeedback.confirm(
        context,
        title: 'Eliminar movimiento',
        message:
            '¿Eliminar "${tx.descripcion}"? El saldo de la cuenta se revertirá.',
      ),
      onDismissed: (_) => _delete(context, ref),
      child: Material(
        color: colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: () => showTransactionSheet(
            context,
            dateStr: tx.fecha,
            transaction: tx,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Icon(
                    tx.isIncome
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.descripcion,
                        style: text.titleSmall?.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (accountName != null) accountName!,
                          tx.categoria,
                          if (tx.cuotas > 1) '${tx.cuotas} cuotas',
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  AppCurrency.signed(tx.monto, isIncome: tx.isIncome),
                  style: text.titleSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .deleteTransaction(transaction.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Movimiento eliminado');
      }
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
      // Recarga para restaurar la fila descartada visualmente.
      await ref.read(dashboardControllerProvider.notifier).refreshMonth();
    }
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({required this.transfer, required this.accountNames});

  final Transfer transfer;
  final Map<int, String> accountNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded,
              size: 20, color: AppColors.sky),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.descripcion?.isNotEmpty == true
                      ? transfer.descripcion!
                      : 'Transferencia',
                  style: text.titleSmall?.copyWith(fontSize: 13),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        accountNames[transfer.cuentaOrigenId] ?? 'Origen',
                        style: text.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: AppColors.expense,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 11, color: colors.textTertiary),
                    Flexible(
                      child: Text(
                        accountNames[transfer.cuentaDestinoId] ?? 'Destino',
                        style: text.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: AppColors.income,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      ' · ${AppDate.medium(transfer.fecha)}',
                      style: text.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            AppCurrency.format(transfer.monto),
            style: text.titleSmall?.copyWith(color: AppColors.sky),
          ),
          IconButton(
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            color: AppColors.danger,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar transferencia',
      message: 'Se revertirán los saldos de ambas cuentas.',
    );
    if (!ok) return;

    try {
      await ref.read(financeRepositoryProvider).deleteTransfer(transfer.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Transferencia eliminada');
      }
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
    }
  }
}
