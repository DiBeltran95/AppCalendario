import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/models/finance.dart';

/// Cálculos derivados del módulo de finanzas.
///
/// Port de los bloques reactivos del Dashboard web: regla 50/30/20, consejos
/// del "experto" y estado de presupuestos. Son funciones puras sobre los datos
/// del mes, sin estado propio.
class FinanceInsights {
  FinanceInsights({
    required this.bootstrap,
    required this.monthData,
  });

  final BootstrapData bootstrap;
  final MonthData monthData;

  // --- Agregados básicos ---

  late final double totalSavings = bootstrap.cuentas
      .where((c) =>
          c.tipo == AccountType.savings ||
          c.tipo == AccountType.cash ||
          c.tipo == AccountType.cdt)
      .fold(0.0, (sum, c) => sum + c.saldo);

  late final double totalCreditDebt = bootstrap.cuentas
      .where((c) => c.isCreditCard)
      .fold(0.0, (sum, c) => sum + c.saldo);

  late final double totalCreditLimit = bootstrap.cuentas
      .where((c) => c.isCreditCard)
      .fold(0.0, (sum, c) => sum + c.limite);

  double get creditUsageRatio =>
      totalCreditLimit > 0 ? (totalCreditDebt / totalCreditLimit) * 100 : 0;

  late final double monthlyIncome = monthData.transacciones
      .where((t) => t.isIncome)
      .fold(0.0, (sum, t) => sum + t.monto);

  late final double monthlyExpense = monthData.transacciones
      .where((t) => t.isExpense)
      .fold(0.0, (sum, t) => sum + t.monto);

  double get monthlyBalance => monthlyIncome - monthlyExpense;

  double get savingsRate => monthlyIncome > 0
      ? ((monthlyIncome - monthlyExpense) / monthlyIncome) * 100
      : 0;

  /// Gasto por categoría del mes.
  late final Map<String, double> expenseByCategory = () {
    final map = <String, double>{};
    for (final t in monthData.transacciones) {
      if (t.isExpense) {
        map[t.categoria] = (map[t.categoria] ?? 0) + t.monto;
      }
    }
    return map;
  }();

  ({String category, double amount})? get topExpenseCategory {
    String? cat;
    var max = 0.0;
    expenseByCategory.forEach((k, v) {
      if (v > max) {
        max = v;
        cat = k;
      }
    });
    return cat == null ? null : (category: cat!, amount: max);
  }

  // --- Regla 50/30/20 ---

  static const _needsSlugs = {
    'comida', 'mercado', 'transporte', 'servicios', 'salud', 'medicina',
    'medicamentos', 'educacion', 'arriendo', 'alquiler', 'vivienda', 'hogar',
    'home', 'agua', 'luz', 'gas', 'internet', 'electricidad',
    'transporte_publico', 'gasolina',
  };
  static const _savingsSlugs = {'ahorro', 'ahorros', 'inversion', 'inversiones'};

  static String classify503020(String slug) {
    final s = slug.toLowerCase();
    if (_savingsSlugs.contains(s)) return 'ahorro';
    if (_needsSlugs.contains(s)) return 'necesidades';
    return 'deseos';
  }

  late final Rule503020 rule503020 = () {
    final income = monthlyIncome;
    var needs = 0.0, wants = 0.0;
    for (final t in monthData.transacciones) {
      if (!t.isExpense) continue;
      switch (classify503020(t.categoria)) {
        case 'necesidades':
          needs += t.monto;
        case 'deseos':
          wants += t.monto;
        // 'ahorro' no suma como gasto: queda en el bloque de ahorro.
      }
    }
    final savings = income - needs - wants;
    double pct(double v) => income > 0 ? (v / income) * 100 : 0;

    RuleStatus status(double p, double ok, double warn) =>
        p <= ok ? RuleStatus.ok : (p <= warn ? RuleStatus.warn : RuleStatus.bad);

    final savingsPct = pct(savings);
    return Rule503020(
      income: income,
      needs: needs,
      wants: wants,
      savings: savings,
      needsPct: pct(needs),
      wantsPct: pct(wants),
      savingsPct: savingsPct,
      needsStatus: status(pct(needs), 50, 60),
      wantsStatus: status(pct(wants), 30, 40),
      savingsStatus: savingsPct >= 20
          ? RuleStatus.ok
          : (savingsPct >= 10 ? RuleStatus.warn : RuleStatus.bad),
    );
  }();

  // --- Consejos del experto ---

  late final List<Advice> recommendations = () {
    final list = <Advice>[];

    if (monthlyIncome > 0) {
      final rate = savingsRate;
      if (rate < 0) {
        list.add(Advice(
          type: AdviceType.danger,
          icon: Icons.trending_down_rounded,
          title: 'Presupuesto deficitario',
          text:
              '¡Cuidado! Este mes tus gastos superan tus ingresos por ${AppCurrency.format(monthlyBalance.abs())}. Tu tasa de ahorro es de ${rate.toStringAsFixed(1)}%. Revisa tus gastos de inmediato.',
        ));
      } else if (rate < 10) {
        list.add(Advice(
          type: AdviceType.warning,
          icon: Icons.warning_rounded,
          title: 'Ahorro insuficiente',
          text:
              'Estás ahorrando solo el ${rate.toStringAsFixed(1)}% de tus ingresos. Los expertos recomiendan destinar al menos el 20% al ahorro (regla 50/30/20). Intenta recortar deseos.',
        ));
      } else if (rate < 20) {
        list.add(Advice(
          type: AdviceType.info,
          icon: Icons.trending_up_rounded,
          title: 'Buen ritmo de ahorro',
          text:
              'Tu tasa de ahorro mensual es de ${rate.toStringAsFixed(1)}%. ¡Sigue así! Automatiza ese dinero apenas llegue a tu cuenta para no tentarte a gastarlo.',
        ));
      } else {
        list.add(Advice(
          type: AdviceType.success,
          icon: Icons.stars_rounded,
          title: 'Excelente nivel de ahorro',
          text:
              '¡Felicidades! Estás ahorrando el ${rate.toStringAsFixed(1)}% de tus ingresos. Considera poner una parte a rentar en un CDT o en fondos de inversión.',
        ));
      }
    } else {
      list.add(const Advice(
        type: AdviceType.info,
        icon: Icons.info_rounded,
        title: 'Registra tus movimientos',
        text:
            'Registra tus ingresos y gastos para que podamos analizar tu tasa de ahorro y darte recomendaciones útiles.',
      ));
    }

    if (totalCreditLimit > 0) {
      final usage = creditUsageRatio;
      if (usage > 50) {
        list.add(Advice(
          type: AdviceType.danger,
          icon: Icons.credit_card_off_rounded,
          title: 'Alto endeudamiento en tarjetas',
          text:
              'Estás usando el ${usage.toStringAsFixed(1)}% de tu cupo en tarjetas de crédito. Esto puede afectar tu score financiero. Intenta pagar la totalidad a una cuota.',
        ));
      } else if (usage > 30) {
        list.add(Advice(
          type: AdviceType.warning,
          icon: Icons.credit_card_rounded,
          title: 'Uso de tarjeta medio',
          text:
              'Has ocupado el ${usage.toStringAsFixed(1)}% de tu límite en tarjetas. Mantenerlo por debajo del 30% optimiza tu historial de crédito.',
        ));
      } else {
        list.add(Advice(
          type: AdviceType.success,
          icon: Icons.credit_score_rounded,
          title: 'Uso de tarjeta ideal',
          text:
              'Uso de tarjetas óptimo (${usage.toStringAsFixed(1)}%). Estás utilizando el crédito de forma responsable.',
        ));
      }
    }

    final top = topExpenseCategory;
    if (top != null && top.amount > 0) {
      final label = bootstrap.categorias
          .where((c) => c.valor == top.category)
          .map((c) => c.label)
          .firstOrNull ??
          top.category;
      list.add(Advice(
        type: AdviceType.info,
        icon: Icons.pie_chart_rounded,
        title: 'Mayor gasto: $label',
        text:
            'Tu mayor egreso del mes es en "$label" por ${AppCurrency.format(top.amount)}. ¿Se puede optimizar?',
      ));
    }

    final hasCdt = bootstrap.cuentas.any((c) => c.isCdt);
    if (totalSavings > 1000000 && !hasCdt) {
      list.add(Advice(
        type: AdviceType.info,
        icon: Icons.account_balance_rounded,
        title: 'Haz crecer tu dinero',
        text:
            'Tienes ahorros por ${AppCurrency.format(totalSavings)}. Puedes rentabilizar una parte con un CDT de 90 o 180 días de bajo riesgo.',
      ));
    }

    return list;
  }();

  // --- Presupuestos ---

  BudgetStatus budgetStatusFor(String categoria) {
    final spent = expenseByCategory[categoria] ?? 0;
    final budget =
        monthData.presupuestos.where((b) => b.categoria == categoria).firstOrNull;
    if (budget == null) {
      return BudgetStatus(spent: spent, limit: 0, pct: 0, budgetId: null);
    }
    final pct = budget.montoLimite > 0
        ? ((spent / budget.montoLimite) * 100).clamp(0, 100).roundToDouble()
        : 0.0;
    return BudgetStatus(
      spent: spent,
      limit: budget.montoLimite,
      pct: pct,
      budgetId: budget.id,
    );
  }
}

enum RuleStatus {
  ok(AppColors.income, Icons.check_circle_rounded),
  warn(AppColors.warning, Icons.warning_rounded),
  bad(AppColors.danger, Icons.error_rounded);

  const RuleStatus(this.color, this.icon);
  final Color color;
  final IconData icon;
}

class Rule503020 {
  const Rule503020({
    required this.income,
    required this.needs,
    required this.wants,
    required this.savings,
    required this.needsPct,
    required this.wantsPct,
    required this.savingsPct,
    required this.needsStatus,
    required this.wantsStatus,
    required this.savingsStatus,
  });

  final double income;
  final double needs;
  final double wants;
  final double savings;
  final double needsPct;
  final double wantsPct;
  final double savingsPct;
  final RuleStatus needsStatus;
  final RuleStatus wantsStatus;
  final RuleStatus savingsStatus;

  bool get hasData => income > 0;
  bool get inDeficit => savings < 0;
}

enum AdviceType {
  danger(AppColors.danger),
  warning(AppColors.warning),
  info(AppColors.info),
  success(AppColors.income);

  const AdviceType(this.color);
  final Color color;
}

class Advice {
  const Advice({
    required this.type,
    required this.icon,
    required this.title,
    required this.text,
  });

  final AdviceType type;
  final IconData icon;
  final String title;
  final String text;
}

class BudgetStatus {
  const BudgetStatus({
    required this.spent,
    required this.limit,
    required this.pct,
    required this.budgetId,
  });

  final double spent;
  final double limit;
  final double pct;
  final int? budgetId;

  bool get hasBudget => budgetId != null;
  bool get overLimit => pct >= 100;
  bool get nearLimit => pct >= 80 && pct < 100;

  Color get color => overLimit
      ? AppColors.danger
      : nearLimit
          ? AppColors.warning
          : AppColors.income;
}
