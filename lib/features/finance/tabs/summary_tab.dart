import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/animated_counter.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/panel_parts.dart';
import '../../shell/dashboard_controller.dart';
import '../finance_insights.dart';

/// Pestaña Resumen: balance del día/mes, regla 50/30/20, proyección de CDT y
/// consejos del experto.
class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key, required this.state, required this.insights});

  final DashboardState state;
  final FinanceInsights insights;

  @override
  Widget build(BuildContext context) {
    final selectedDay = state.selectedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen del día seleccionado.
        if (selectedDay != null) ...[
          FadeSlideIn(child: _DaySummaryCard(state: state)),
          const SizedBox(height: AppSpacing.md),
          if (selectedDay.compareTo(AppDate.today()) > 0)
            FadeSlideIn(
              index: 1,
              child: _CdtProjectionCard(state: state, targetDate: selectedDay),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        FadeSlideIn(index: 1, child: _MonthSummaryCard(insights: insights)),
        const SizedBox(height: AppSpacing.md),

        FadeSlideIn(index: 2, child: _Rule503020Card(rule: insights.rule503020)),
        const SizedBox(height: AppSpacing.md),

        FadeSlideIn(index: 3, child: _AdviceList(advice: insights.recommendations)),
      ],
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final txs = state.selectedDayTransactions;
    final income = txs
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.monto);
    final expense = txs
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.monto);
    final balance = income - expense;

    final tip = income == 0 && expense == 0
        ? 'Sin movimientos este día. Mantener un día libre de gastos es excelente para tu salud financiera.'
        : expense > income
            ? 'Los egresos superan los ingresos del día. Limita las compras de impulso y compensa con días de cero gastos.'
            : '¡Bien! Recibiste un ingreso. Es el momento perfecto para destinar una parte al ahorro o a tus metas.';

    return AppCard(
      accent: AppColors.income,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Resumen del día',
            icon: Icons.today_rounded,
            color: AppColors.income,
          ),
          StatRow(
            label: 'Ingresos:',
            value: AppCurrency.format(income),
            valueColor: AppColors.income,
          ),
          const SizedBox(height: AppSpacing.xs),
          StatRow(
            label: 'Gastos:',
            value: AppCurrency.format(expense),
            valueColor: AppColors.expense,
          ),
          StatRow(
            label: 'Balance del día:',
            value: AppCurrency.format(balance),
            valueColor: balance >= 0 ? AppColors.income : AppColors.expense,
            bold: true,
            divider: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  size: 15, color: AppColors.income),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tip,
                  style: text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.insights});

  final FinanceInsights insights;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final balance = insights.monthlyBalance;

    return AppCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Resumen mensual',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.gold,
          ),

          // El balance neto protagonista, contando desde cero.
          Center(
            child: Column(
              children: [
                Text(
                  'BALANCE NETO DEL MES',
                  style: text.labelSmall?.copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(height: AppSpacing.xs),
                AnimatedCounter(
                  value: balance,
                  style: text.headlineMedium?.copyWith(
                    color:
                        balance >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          StatRow(
            label: 'Total ingresos:',
            value: AppCurrency.format(insights.monthlyIncome),
            valueColor: AppColors.income,
          ),
          const SizedBox(height: AppSpacing.xs),
          StatRow(
            label: 'Total gastos:',
            value: AppCurrency.format(insights.monthlyExpense),
            valueColor: AppColors.expense,
          ),
          if (insights.totalCreditLimit > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            StatRow(
              label: 'Uso de tarjetas:',
              value: '${insights.creditUsageRatio.toStringAsFixed(1)}%',
              valueColor: insights.creditUsageRatio > 50
                  ? AppColors.danger
                  : insights.creditUsageRatio > 30
                      ? AppColors.warning
                      : AppColors.income,
            ),
          ],
        ],
      ),
    );
  }
}

/// Regla 50/30/20 con barra apilada y filas comparativas.
class _Rule503020Card extends StatelessWidget {
  const _Rule503020Card({required this.rule});

  final Rule503020 rule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      accent: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Regla 50 / 30 / 20',
            icon: Icons.balance_rounded,
            color: AppColors.sky,
          ),
          Text(
            'Distribución ideal: 50% necesidades, 30% deseos, 20% ahorro.',
            style: text.bodySmall?.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: AppSpacing.md),

          if (!rule.hasData)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.bgPrimary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                'Registra ingresos este mes para ver cómo se distribuye tu dinero.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            // Barra apilada: los tres segmentos crecen en secuencia.
            _StackedBar(rule: rule),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                rule.inDeficit
                    ? '⚠ Estás gastando más de lo que ingresas'
                    : 'Distribución de ${AppCurrency.format(rule.income)} en ingresos',
                style: text.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: rule.inDeficit
                      ? AppColors.danger
                      : colors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _RuleRow(
              label: 'Necesidades',
              sub: 'Vivienda, comida, servicios, salud, transporte',
              ideal: '50%',
              color: AppColors.phaseFollicular,
              pct: rule.needsPct,
              value: rule.needs,
              status: rule.needsStatus,
              index: 0,
            ),
            _RuleRow(
              label: 'Deseos',
              sub: 'Ocio, entretenimiento, antojos',
              ideal: '30%',
              color: AppColors.warning,
              pct: rule.wantsPct,
              value: rule.wants,
              status: rule.wantsStatus,
              index: 1,
            ),
            _RuleRow(
              label: 'Ahorro / Deuda',
              sub: 'Lo que no gastas + abonos a ahorro',
              ideal: '20%',
              color: AppColors.income,
              pct: rule.savingsPct,
              value: rule.savings,
              status: rule.savingsStatus,
              index: 2,
            ),

            const SizedBox(height: AppSpacing.sm),
            _Diagnosis(rule: rule),
          ],
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.rule});

  final Rule503020 rule;

  @override
  Widget build(BuildContext context) {
    final segments = [
      (rule.needsPct, AppColors.phaseFollicular),
      (rule.wantsPct, AppColors.warning),
      (rule.savingsPct.clamp(0.0, 100.0), AppColors.income),
    ];
    final total = segments.fold(0.0, (sum, s) => sum + s.$1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: SizedBox(
        height: 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 900),
          curve: Curves.easeOutQuint,
          builder: (context, t, _) => Row(
            children: [
              for (final (pct, color) in segments)
                if (pct > 0)
                  Expanded(
                    flex: ((pct / (total == 0 ? 1 : total)) * 1000 * t)
                            .round()
                            .clamp(1, 1000),
                    child: ColoredBox(color: color),
                  ),
              if (total < 100 || total == 0)
                Expanded(
                  flex: (((100 - total).clamp(0, 100) / 100) * 1000)
                          .round()
                          .clamp(1, 1000),
                  child: ColoredBox(
                    color: AppColors.danger.withValues(alpha: 0.15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.label,
    required this.sub,
    required this.ideal,
    required this.color,
    required this.pct,
    required this.value,
    required this.status,
    required this.index,
  });

  final String label;
  final String sub;
  final String ideal;
  final Color color;
  final double pct;
  final double value;
  final RuleStatus status;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return FadeSlideIn(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(label,
                      style: text.titleSmall?.copyWith(fontSize: 13)),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: text.titleSmall?.copyWith(color: status.color),
                ),
                Text(' / ideal $ideal',
                    style: text.bodySmall?.copyWith(fontSize: 10.5)),
                const SizedBox(width: AppSpacing.xs),
                Icon(status.icon, size: 15, color: status.color),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(sub,
                      style: text.bodySmall?.copyWith(fontSize: 10.5)),
                ),
                Text(
                  AppCurrency.format(value),
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Diagnosis extends StatelessWidget {
  const _Diagnosis({required this.rule});

  final Rule503020 rule;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final message = rule.inDeficit
        ? 'Tus gastos superan tus ingresos este mes. Prioriza reducir los "deseos" y revisa si alguna "necesidad" se puede optimizar.'
        : rule.savingsStatus == RuleStatus.ok && rule.needsStatus == RuleStatus.ok
            ? '¡Excelente equilibrio! Estás cumpliendo la regla 50/30/20. Mantén el ritmo y considera invertir tu ahorro.'
            : rule.savingsStatus == RuleStatus.bad
                ? 'Tu ahorro está por debajo del 20% recomendado. Recorta gastos en "deseos" para fortalecer tu colchón.'
                : rule.needsStatus == RuleStatus.bad
                    ? 'Tus necesidades consumen más del 60% de tus ingresos. Evalúa gastos fijos como vivienda o servicios.'
                    : 'Vas por buen camino. Pequeños ajustes en "deseos" te acercarán al ahorro ideal del 20%.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              size: 15, color: AppColors.sky),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: text.bodySmall?.copyWith(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

/// Proyección de rendimientos de CDT a la fecha futura seleccionada.
class _CdtProjectionCard extends StatelessWidget {
  const _CdtProjectionCard({required this.state, required this.targetDate});

  final DashboardState state;
  final String targetDate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cdts = state.bootstrap.cuentas
        .where((c) => c.isCdt && c.interesTasa > 0)
        .toList();
    if (cdts.isEmpty) return const SizedBox.shrink();

    final currentTotal = cdts.fold(0.0, (sum, c) => sum + c.saldo);
    final projectedTotal =
        cdts.fold(0.0, (sum, c) => sum + c.projectedBalanceAt(targetDate));
    final yield_ = projectedTotal - currentTotal;

    return AppCard(
      accent: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Proyección de rendimientos',
            icon: Icons.insights_rounded,
            color: AppColors.sky,
            trailing: StatusPill(
              label: AppDate.medium(targetDate),
              color: AppColors.sky,
            ),
          ),
          Center(
            child: Column(
              children: [
                Text(
                  'INTERÉS ACUMULADO ESTIMADO',
                  style: text.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: AppSpacing.xs),
                AnimatedCounter(
                  value: yield_,
                  formatter: (v) => '+${AppCurrency.format(v)}',
                  style: text.headlineSmall?.copyWith(color: AppColors.income),
                ),
                Text(
                  'Saldo proyectado: ${AppCurrency.format(projectedTotal)}',
                  style: text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final cdt in cdts) ...[
            StatRow(
              label: cdt.nombre,
              value:
                  '+${AppCurrency.format(cdt.projectedBalanceAt(targetDate) - cdt.saldo)}',
              valueColor: AppColors.sky,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _AdviceList extends StatelessWidget {
  const _AdviceList({required this.advice});

  final List<Advice> advice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Consejos del experto',
            icon: Icons.support_agent_rounded,
            color: AppColors.gold,
          ),
          for (var i = 0; i < advice.length; i++)
            FadeSlideIn(
              index: i,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border(
                    left: BorderSide(color: advice[i].type.color, width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(advice[i].icon,
                        size: 18, color: advice[i].type.color),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(advice[i].title,
                              style:
                                  text.titleSmall?.copyWith(fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            advice[i].text,
                            style: text.bodySmall
                                ?.copyWith(fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
