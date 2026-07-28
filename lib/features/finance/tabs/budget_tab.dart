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
import '../../../shared/widgets/panel_parts.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../shell/dashboard_controller.dart';
import '../finance_insights.dart';
import '../finance_sheets.dart';

/// Pestaña Presupuesto: límites mensuales por categoría + gestión de
/// categorías propias.
class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key, required this.state, required this.insights});

  final DashboardState state;
  final FinanceInsights insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = state.bootstrap.categorias;
    final usedCategories = () {
      final set = <String>{...state.bootstrap.categoriasUsadas};
      for (final t in state.monthData.transacciones) {
        set.add(t.categoria);
      }
      for (final b in state.monthData.presupuestos) {
        set.add(b.categoria);
      }
      return set;
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Límites de ${state.monthLabel.toLowerCase()}',
          icon: Icons.pie_chart_rounded,
          color: AppColors.warning,
        ),
        Text(
          'Toca una categoría para asignarle un límite mensual. El anillo se llena con tus gastos.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: AppSpacing.md),

        // Grid de categorías con anillo de progreso.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent: 120,
          ),
          itemBuilder: (context, i) {
            final category = categories[i];
            final status = insights.budgetStatusFor(category.valor);
            return FadeSlideIn(
              index: i,
              child: _BudgetCard(
                category: category,
                status: status,
                onTap: () => showBudgetSheet(
                  context,
                  categoria: category.valor,
                  categoriaLabel: category.label,
                  mes: state.month,
                  anio: state.year,
                  currentLimit: status.limit,
                  budgetId: status.budgetId,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),
        SectionTitle(
          title: 'Mis categorías',
          icon: Icons.sell_rounded,
          color: AppColors.gold,
          trailing: TextButton.icon(
            onPressed: () => showCategorySheet(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nueva'),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in categories)
              _CategoryChip(
                category: category,
                // Las categorías por defecto y las que ya tienen movimientos
                // no se pueden borrar.
                deletable: !category.esDefault &&
                    !usedCategories.contains(category.valor),
                onDelete: () => _deleteCategory(context, ref, category),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    FinanceCategory category,
  ) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar categoría',
      message: '¿Eliminar "${category.label}"?',
    );
    if (!ok) return;

    try {
      await ref.read(financeRepositoryProvider).deleteCategory(category.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Categoría eliminada');
      }
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.category,
    required this.status,
    required this.onTap,
  });

  final FinanceCategory category;
  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Material(
      color: colors.bgTertiary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: status.overLimit
                  ? AppColors.danger.withValues(alpha: 0.5)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              _PulsingRing(
                overLimit: status.overLimit,
                child: ProgressRing(
                  progress: status.hasBudget ? status.pct / 100 : 0,
                  size: 52,
                  strokeWidth: 5,
                  color: status.color,
                  child: Icon(category.iconData,
                      size: 18, color: status.color),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: text.titleSmall?.copyWith(fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (status.hasBudget) ...[
                      Text(
                        AppCurrency.compact(status.spent),
                        style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: status.color,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'de ${AppCurrency.compact(status.limit)}',
                        style: text.bodySmall?.copyWith(fontSize: 10.5),
                      ),
                    ] else
                      Text(
                        status.spent > 0
                            ? '${AppCurrency.compact(status.spent)} sin límite'
                            : 'Sin límite',
                        style: text.bodySmall?.copyWith(fontSize: 10.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hace pulsar el anillo cuando el presupuesto se ha superado.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.child, required this.overLimit});

  final Widget child;
  final bool overLimit;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.overLimit) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overLimit != oldWidget.overLimit) {
      if (widget.overLimit) {
        _controller.repeat(reverse: true);
      } else {
        _controller
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.overLimit || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: 1 + _controller.value * 0.06,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.deletable,
    required this.onDelete,
  });

  final FinanceCategory category;
  final bool deletable;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.iconData, size: 14, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            category.label,
            style: TextStyle(fontSize: 12, color: colors.textPrimary),
          ),
          if (deletable) ...[
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.danger.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
