import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/finance.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/animated_counter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/panel_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../shell/dashboard_controller.dart';

/// Rango de tiempo de las gráficas, igual que los filtros de la web.
enum AnalyticsRange {
  week7('7D', 7),
  days30('30D', 30),
  months3('3M', 90),
  months6('6M', 180),
  year1('1A', 365);

  const AnalyticsRange(this.label, this.days);
  final String label;
  final int days;
}

/// Estado de la pestaña de gráficos: carga perezosa por rango, igual que la
/// web (solo trae datos al abrir la pestaña, y solo del rango elegido).
class AnalyticsController extends Notifier<AnalyticsState> {
  @override
  AnalyticsState build() {
    Future.microtask(() => load(AnalyticsRange.days30));
    return const AnalyticsState();
  }

  Future<void> load(AnalyticsRange range) async {
    state = AnalyticsState(range: range, loading: true, data: state.data);
    try {
      final data =
          await ref.read(financeRepositoryProvider).fetchAnalytics(range.days);
      state = AnalyticsState(range: range, loading: false, data: data);
    } on ApiException catch (e) {
      state = AnalyticsState(
        range: range,
        loading: false,
        data: state.data,
        error: e.message,
      );
    }
  }
}

class AnalyticsState {
  const AnalyticsState({
    this.range = AnalyticsRange.days30,
    this.loading = true,
    this.data = const [],
    this.error,
  });

  final AnalyticsRange range;
  final bool loading;
  final List<FinanceTransaction> data;
  final String? error;
}

final analyticsControllerProvider =
    NotifierProvider<AnalyticsController, AnalyticsState>(
  AnalyticsController.new,
);

/// Pestaña Gráficos.
class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsControllerProvider);
    final dashboard = ref.watch(dashboardControllerProvider);
    final accounts = dashboard.bootstrap.cuentas;
    final categories = dashboard.bootstrap.categorias;

    final txs = analytics.data;
    final incomes = txs.where((t) => t.isIncome).toList();
    final expenses = txs.where((t) => t.isExpense).toList();
    final totalIncome = incomes.fold(0.0, (sum, t) => sum + t.monto);
    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.monto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filtro de rango.
        Row(
          children: [
            for (final range in AnalyticsRange.values) ...[
              Expanded(
                child: _RangeChip(
                  range: range,
                  active: range == analytics.range,
                  onTap: () => ref
                      .read(analyticsControllerProvider.notifier)
                      .load(range),
                ),
              ),
              if (range != AnalyticsRange.values.last)
                const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        if (analytics.loading && txs.isEmpty)
          const ListSkeleton(count: 3, height: 160)
        else if (txs.isEmpty)
          const EmptyState(
            icon: Icons.query_stats_rounded,
            title: 'Sin datos en este rango',
            message:
                'Registra movimientos para ver la evolución de tu dinero.',
            color: AppColors.gold,
            compact: true,
          )
        else ...[
          // KPIs.
          FadeSlideIn(
            child: Row(
              children: [
                Expanded(
                  child: _Kpi(
                    label: 'Ingresos',
                    value: totalIncome,
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Kpi(
                    label: 'Gastos',
                    value: totalExpense,
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Kpi(
                    label: 'Balance',
                    value: totalIncome - totalExpense,
                    color: totalIncome >= totalExpense
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(
            index: 1,
            child: _ChartCard(
              title: 'Evolución del patrimonio',
              icon: Icons.show_chart_rounded,
              child: _NetWorthChart(
                transactions: txs,
                accounts: accounts,
                days: analytics.range.days,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(
            index: 2,
            child: _ChartCard(
              title: 'Flujo diario',
              icon: Icons.bar_chart_rounded,
              child: _DailyFlowChart(
                transactions: txs,
                days: analytics.range.days,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(
            index: 3,
            child: _ChartCard(
              title: 'Distribución de gastos',
              icon: Icons.donut_large_rounded,
              child: _ExpenseDonut(expenses: expenses, categories: categories),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(
            index: 4,
            child: _ChartCard(
              title: 'Top gastos',
              icon: Icons.trending_down_rounded,
              child: _TopExpenses(expenses: expenses, categories: categories),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          FadeSlideIn(
            index: 5,
            child: _ChartCard(
              title: 'Balance por cuenta',
              icon: Icons.account_balance_rounded,
              child: _AccountBalances(accounts: accounts),
            ),
          ),
        ],
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.range,
    required this.active,
    required this.onTap,
  });

  final AnalyticsRange range;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: AnimatedContainer(
          duration: AppMotion.scale(context, AppMotion.standard),
          curve: AppMotion.emphasizedCurve,
          height: 34,
          decoration: BoxDecoration(
            color: active
                ? colors.accent.withValues(alpha: 0.16)
                : colors.bgTertiary,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: active ? colors.accent : colors.border,
            ),
          ),
          child: Center(
            child: Text(
              range.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? colors.accent : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: text.labelSmall?.copyWith(fontSize: 9)),
          const SizedBox(height: AppSpacing.xs),
          AnimatedCounter(
            value: value,
            formatter: AppCurrency.compact,
            style: text.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: title, icon: icon, color: AppColors.gold),
          child,
        ],
      ),
    );
  }
}

/// Tendencia de patrimonio: saldo actual proyectado hacia atrás restando los
/// movimientos, igual que el cálculo de la web.
class _NetWorthChart extends StatelessWidget {
  const _NetWorthChart({
    required this.transactions,
    required this.accounts,
    required this.days,
  });

  final List<FinanceTransaction> transactions;
  final List<Account> accounts;
  final int days;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Balance actual de todas las cuentas (la tarjeta resta).
    var balance = accounts.fold(
      0.0,
      (sum, a) => sum + (a.tipo.isAsset ? a.saldo : -a.saldo),
    );

    // Se camina hacia atrás desde hoy deshaciendo los movimientos de cada día.
    final byDate = <String, double>{};
    for (final t in transactions) {
      byDate[t.fecha] = (byDate[t.fecha] ?? 0) + t.signedAmount;
    }

    final today = AppDate.today();
    final points = <FlSpot>[];
    final values = <double>[];
    for (var i = 0; i < days; i++) {
      final date = AppDate.addDays(today, -i);
      values.add(balance);
      balance -= byDate[date] ?? 0;
    }
    for (var i = 0; i < values.length; i++) {
      points.add(FlSpot(
        (values.length - 1 - i).toDouble(),
        values[i],
      ));
    }
    points.sort((a, b) => a.x.compareTo(b.x));

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.divider.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  AppCurrency.compact(value),
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => colors.bgHover,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    AppCurrency.format(spot.y),
                    TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 2.4,
              color: colors.accent,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.accent.withValues(alpha: 0.25),
                    colors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: AppMotion.scale(context, AppMotion.dramatic),
        curve: AppMotion.reveal,
      ),
    );
  }
}

/// Flujo diario: barras de ingreso y gasto por día, agregadas por semana en
/// rangos largos para que no se apelmacen.
class _DailyFlowChart extends StatelessWidget {
  const _DailyFlowChart({required this.transactions, required this.days});

  final List<FinanceTransaction> transactions;
  final int days;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Cubos: días sueltos hasta 30, semanas después.
    final bucketSize = days <= 30 ? 1 : 7;
    final bucketCount = (days / bucketSize).ceil().clamp(1, 60);
    final today = AppDate.today();

    final incomes = List.filled(bucketCount, 0.0);
    final expenses = List.filled(bucketCount, 0.0);

    for (final t in transactions) {
      final age = AppDate.daysBetween(t.fecha, today);
      if (age < 0 || age >= days) continue;
      final bucket = bucketCount - 1 - (age ~/ bucketSize);
      if (bucket < 0 || bucket >= bucketCount) continue;
      if (t.isIncome) {
        incomes[bucket] += t.monto;
      } else {
        expenses[bucket] += t.monto;
      }
    }

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colors.bgHover,
              getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                AppCurrency.format(rod.toY),
                TextStyle(
                  color: rodIndex == 0 ? AppColors.income : AppColors.expense,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bucketCount; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: incomes[i],
                    color: AppColors.income,
                    width: days <= 30 ? 4 : 6,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  BarChartRodData(
                    toY: expenses[i],
                    color: AppColors.expense,
                    width: days <= 30 ? 4 : 6,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
        duration: AppMotion.scale(context, AppMotion.dramatic),
        curve: AppMotion.reveal,
      ),
    );
  }
}

/// Donut de gastos por categoría con leyenda en cascada.
class _ExpenseDonut extends StatelessWidget {
  const _ExpenseDonut({required this.expenses, required this.categories});

  final List<FinanceTransaction> expenses;
  final List<FinanceCategory> categories;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final byCategory = <String, double>{};
    for (final t in expenses) {
      byCategory[t.categoria] = (byCategory[t.categoria] ?? 0) + t.monto;
    }
    final total = byCategory.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Sin gastos en el rango.', style: text.bodySmall),
      );
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String labelFor(String slug) =>
        categories.where((c) => c.valor == slug).map((c) => c.label).firstOrNull ??
        slug;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 46,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: FinanceCategory.colorFor(
                      entries[i].key,
                      fallbackIndex: i,
                    ),
                    radius: 34,
                    showTitle: entries[i].value / total > 0.08,
                    title:
                        '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            duration: AppMotion.scale(context, AppMotion.dramatic),
            curve: AppMotion.reveal,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < entries.length && i < 8; i++)
              FadeSlideIn(
                index: i,
                offset: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: FinanceCategory.colorFor(
                          entries[i].key,
                          fallbackIndex: i,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${labelFor(entries[i].key)} · ${AppCurrency.compact(entries[i].value)}',
                      style: text.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Top de gastos individuales del rango.
class _TopExpenses extends StatelessWidget {
  const _TopExpenses({required this.expenses, required this.categories});

  final List<FinanceTransaction> expenses;
  final List<FinanceCategory> categories;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = [...expenses]..sort((a, b) => b.monto.compareTo(a.monto));
    final list = top.take(5).toList();
    final max = list.isEmpty ? 1.0 : list.first.monto;

    return Column(
      children: [
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        list[i].descripcion,
                        style: text.bodySmall?.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppCurrency.format(list[i].monto),
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: list[i].monto / max),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Duration(milliseconds: 500 + i * 100),
                  curve: AppMotion.reveal,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor: context.colors.bgHover,
                      valueColor: AlwaysStoppedAnimation(
                        FinanceCategory.colorFor(
                          list[i].categoria,
                          fallbackIndex: i,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Balance por cuenta como barras horizontales.
class _AccountBalances extends StatelessWidget {
  const _AccountBalances({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Sin cuentas registradas.', style: text.bodySmall),
      );
    }

    final max = accounts.fold(
      1.0,
      (m, a) => a.saldo.abs() > m ? a.saldo.abs() : m,
    );

    return Column(
      children: [
        for (var i = 0; i < accounts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(accounts[i].tipo.icon,
                    size: 15, color: accounts[i].color),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 90,
                  child: Text(
                    accounts[i].nombre,
                    style: text.bodySmall?.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: (accounts[i].saldo.abs() / max).clamp(0.02, 1),
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Duration(milliseconds: 500 + i * 80),
                    curve: AppMotion.reveal,
                    builder: (context, value, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: accounts[i].isCreditCard
                                ? AppColors.expense
                                : accounts[i].color,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppCurrency.compact(accounts[i].saldo),
                  style: text.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accounts[i].isCreditCard
                        ? AppColors.expense
                        : AppColors.income,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
