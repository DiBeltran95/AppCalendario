import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/panel_parts.dart';
import '../../shared/widgets/skeleton.dart';
import '../shell/dashboard_controller.dart';
import 'finance_insights.dart';
import 'tabs/accounts_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/budget_tab.dart';
import 'tabs/goals_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/planner_tab.dart';
import 'tabs/summary_tab.dart';

/// Sub-pestañas del módulo de finanzas, las mismas siete de la versión web.
enum FinanceTab {
  summary('Resumen', Icons.analytics_rounded),
  accounts('Cuentas', Icons.credit_card_rounded),
  goals('Metas', Icons.flag_rounded),
  budget('Presupuesto', Icons.pie_chart_rounded),
  planner('Plan', Icons.schedule_rounded),
  history('Historial', Icons.history_rounded),
  charts('Gráficos', Icons.query_stats_rounded);

  const FinanceTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

final financeTabProvider =
    NotifierProvider<FinanceTabController, FinanceTab>(FinanceTabController.new);

class FinanceTabController extends Notifier<FinanceTab> {
  @override
  FinanceTab build() => FinanceTab.summary;

  void select(FinanceTab tab) => state = tab;
}

/// Panel del módulo Finanzas.
class FinancePanel extends ConsumerWidget {
  const FinancePanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final tab = ref.watch(financeTabProvider);

    final insights = FinanceInsights(
      bootstrap: state.bootstrap,
      monthData: state.monthData,
    );

    return Column(
      children: [
        // Barra de pestañas scrollable con la píldora de selección.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              for (final t in FinanceTab.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _TabChip(
                    tab: t,
                    active: t == tab,
                    onTap: () {
                      AppFeedback.select();
                      ref.read(financeTabProvider.notifier).select(t);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              HintBar(text: AppModule.finance.hint, icon: Icons.payments_rounded),
              const SizedBox(height: AppSpacing.md),

              if (state.selectedDay != null) ...[
                SelectedDayHeader(
                  dateStr: state.selectedDay!,
                  subtitle: 'Filtrando finanzas por este día',
                  icon: Icons.filter_alt_rounded,
                  accent: AppColors.gold,
                  onClear: controller.clearSelection,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (state.loading)
                const ListSkeleton(count: 4)
              else
                // El contenido de la pestaña entra con un fundido corto.
                AnimatedSwitcher(
                  duration: AppMotion.scale(context, AppMotion.standard),
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.015),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(tab),
                    child: switch (tab) {
                      FinanceTab.summary =>
                        SummaryTab(state: state, insights: insights),
                      FinanceTab.accounts =>
                        AccountsTab(state: state),
                      FinanceTab.goals => GoalsTab(state: state),
                      FinanceTab.budget =>
                        BudgetTab(state: state, insights: insights),
                      FinanceTab.planner => PlannerTab(state: state),
                      FinanceTab.history => HistoryTab(state: state),
                      FinanceTab.charts => const AnalyticsTab(),
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final FinanceTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: AppMotion.scale(context, AppMotion.standard),
          curve: AppMotion.emphasizedCurve,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: active
                ? colors.accent.withValues(alpha: 0.16)
                : colors.bgTertiary,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active ? colors.accent : colors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                tab.icon,
                size: 15,
                color: active ? colors.accent : colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              AnimatedDefaultTextStyle(
                duration: AppMotion.scale(context, AppMotion.quick),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? colors.accent : colors.textSecondary,
                ),
                child: Text(tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
