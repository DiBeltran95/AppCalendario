import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/material_icon_map.dart';

/// Tipo de cuenta (`finanzas_cuentas.tipo`).
enum AccountType {
  savings('ahorros', 'Ahorros', Icons.savings_rounded),
  cash('efectivo', 'Efectivo', Icons.account_balance_wallet_rounded),
  checking('corriente', 'Corriente', Icons.account_balance_rounded),
  cdt('cdt', 'CDT / Inversión', Icons.trending_up_rounded),
  creditCard('tarjeta_credito', 'Tarjeta de crédito', Icons.credit_card_rounded),
  other('otro', 'Otra', Icons.wallet_rounded);

  const AccountType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  static AccountType parse(dynamic v) {
    final s = asString(v, fallback: 'ahorros');
    return AccountType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => AccountType.other,
    );
  }

  /// Las cuentas que suman al patrimonio (la tarjeta de crédito resta).
  bool get isAsset => this != AccountType.creditCard;
}

class Account {
  const Account({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.saldo,
    this.limite = 0,
    this.interesTasa = 0,
    this.fechaInicio,
    this.plazoDias = 0,
    this.diaCorte,
  });

  final int id;
  final String nombre;
  final AccountType tipo;

  /// En una tarjeta de crédito representa la **deuda**, no un saldo disponible.
  final double saldo;

  /// Cupo autorizado (solo tarjeta de crédito).
  final double limite;

  /// Tasa efectiva anual, en porcentaje (solo CDT).
  final double interesTasa;

  final String? fechaInicio;

  /// 0 = rendimiento continuo (cajita/bolsillo), sin fecha de vencimiento.
  final int plazoDias;

  final int? diaCorte;

  bool get isCreditCard => tipo == AccountType.creditCard;
  bool get isCdt => tipo == AccountType.cdt;
  bool get hasMaturity => plazoDias > 0;

  /// Porcentaje de cupo usado, 0-100.
  double get creditUsage => limite > 0 ? (saldo / limite) * 100 : 0;

  Color get color => switch (tipo) {
        AccountType.creditCard => const Color(0xFFFF5252),
        AccountType.cdt => const Color(0xFFDAA520),
        _ => const Color(0xFF4CAF50),
      };

  // --- Cálculos de CDT (portados 1:1 desde Dashboard.svelte) ---

  /// Tasa efectiva anual como fracción.
  double get _rate => interesTasa / 100;

  /// Cuánto rinde hoy, en pesos: la E.A. llevada a un solo día.
  double get dailyYield {
    if (interesTasa <= 0 || saldo <= 0) return 0;
    return saldo * (math.pow(1 + _rate, 1 / 365).toDouble() - 1);
  }

  /// Rendimiento total al vencimiento (solo si hay plazo).
  double get totalYield {
    if (!hasMaturity || interesTasa <= 0 || saldo <= 0) return 0;
    return saldo * (math.pow(1 + _rate, plazoDias / 365).toDouble() - 1);
  }

  /// Fecha de vencimiento en `YYYY-MM-DD`, o null si es rendimiento continuo.
  String? get maturityDate {
    if (!hasMaturity || fechaInicio == null) return null;
    return AppDate.addDays(fechaInicio!, plazoDias);
  }

  /// Días que faltan para vencer (0 si ya venció).
  int get daysRemaining {
    final maturity = maturityDate;
    if (maturity == null) return 0;
    final diff = AppDate.daysBetween(AppDate.today(), maturity);
    return diff < 0 ? 0 : diff;
  }

  /// Progreso del plazo, 0-100.
  double get maturityProgress {
    if (!hasMaturity || fechaInicio == null) return 0;
    final elapsed = AppDate.daysBetween(fechaInicio!, AppDate.today());
    if (elapsed <= 0) return 0;
    return math.min(100, (elapsed / plazoDias) * 100);
  }

  /// Saldo proyectado a una fecha futura, capitalizando día a día.
  ///
  /// Si el CDT tiene plazo, la capitalización se detiene en el vencimiento:
  /// pasada esa fecha el saldo ya no crece.
  double projectedBalanceAt(String dateStr) {
    if (!isCdt || interesTasa <= 0) return saldo;

    final today = AppDate.today();
    var days = AppDate.daysBetween(today, dateStr);
    if (days <= 0) return saldo;

    if (hasMaturity) {
      final toMaturity = AppDate.daysBetween(today, maturityDate!);
      if (days > toMaturity) days = math.max(0, toMaturity);
    }
    if (days <= 0) return saldo;

    return saldo * math.pow(1 + _rate, days / 365).toDouble();
  }

  /// Días efectivamente capitalizados hasta [dateStr] y si se topó el plazo.
  /// Lo usa la tarjeta de detalle de proyección.
  ({int total, int compounded, bool cappedAtMaturity}) projectionDetail(
    String dateStr,
  ) {
    final total = AppDate.daysBetween(AppDate.today(), dateStr);
    if (!hasMaturity) {
      return (total: total, compounded: total, cappedAtMaturity: false);
    }
    final toMaturity = AppDate.daysBetween(AppDate.today(), maturityDate!);
    final capped = total > toMaturity;
    return (
      total: total,
      compounded: capped ? math.max(0, toMaturity) : total,
      cappedAtMaturity: capped,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: asInt(json['id']),
        nombre: asString(json['nombre'], fallback: 'Cuenta'),
        tipo: AccountType.parse(json['tipo']),
        saldo: asDouble(json['saldo']),
        limite: asDouble(json['limite']),
        interesTasa: asDouble(json['interes_tasa']),
        fechaInicio: () {
          final v = AppDate.normalize(json['fecha_inicio']);
          return v.isEmpty ? null : v;
        }(),
        plazoDias: asInt(json['plazo_dias']),
        diaCorte: asIntOrNull(json['dia_corte']),
      );
}

/// Movimiento (`finanzas_transacciones`).
class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    this.cuentaId,
    this.categoria = 'otros',
    this.ingresoPlanificadoId,
    this.cuotas = 1,
  });

  final int id;

  /// `ingreso` o `gasto`.
  final String tipo;
  final double monto;
  final String descripcion;
  final String fecha;
  final int? cuentaId;
  final String categoria;
  final int? ingresoPlanificadoId;
  final int cuotas;

  bool get isIncome => tipo == 'ingreso';
  bool get isExpense => !isIncome;

  /// Positivo si entra, negativo si sale.
  double get signedAmount => isIncome ? monto : -monto;

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) =>
      FinanceTransaction(
        id: asInt(json['id']),
        tipo: asString(json['tipo'], fallback: 'gasto'),
        monto: asDouble(json['monto']),
        descripcion: asString(json['descripcion'], fallback: 'Movimiento'),
        fecha: AppDate.normalize(json['fecha']),
        cuentaId: asIntOrNull(json['cuenta_id']),
        categoria: asString(json['categoria'], fallback: 'otros'),
        ingresoPlanificadoId: asIntOrNull(json['ingreso_planificado_id']),
        cuotas: asInt(json['cuotas'], fallback: 1),
      );
}

/// Transferencia entre cuentas propias (`finanzas_transferencias`).
class Transfer {
  const Transfer({
    required this.id,
    required this.cuentaOrigenId,
    required this.cuentaDestinoId,
    required this.monto,
    required this.fecha,
    this.descripcion,
  });

  final int id;
  final int cuentaOrigenId;
  final int cuentaDestinoId;
  final double monto;
  final String fecha;
  final String? descripcion;

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
        id: asInt(json['id']),
        cuentaOrigenId: asInt(json['cuenta_origen_id']),
        cuentaDestinoId: asInt(json['cuenta_destino_id']),
        monto: asDouble(json['monto']),
        fecha: AppDate.normalize(json['fecha']),
        descripcion: asStringOrNull(json['descripcion']),
      );
}

/// Ingreso recurrente planificado (`finanzas_ingresos_planificados`).
class PlannedIncome {
  const PlannedIncome({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.frecuencia,
    required this.fechaInicio,
    this.cuentaId,
    this.activo = true,
  });

  final int id;
  final String descripcion;
  final double monto;

  /// `semanal`, `quincenal`, `mensual`, `bimestral`, `trimestral`, `anual`.
  final String frecuencia;
  final String fechaInicio;
  final int? cuentaId;
  final bool activo;

  factory PlannedIncome.fromJson(Map<String, dynamic> json) => PlannedIncome(
        id: asInt(json['id']),
        descripcion: asString(json['descripcion'], fallback: 'Ingreso'),
        monto: asDouble(json['monto']),
        frecuencia: asString(json['frecuencia'], fallback: 'mensual'),
        fechaInicio: AppDate.normalize(json['fecha_inicio']),
        cuentaId: asIntOrNull(json['cuenta_id']),
        activo: asBool(json['activo'], fallback: true),
      );
}

/// Confirmación de que un ingreso planificado sí llegó
/// (`finanzas_ingresos_verificados`).
class IncomeVerification {
  const IncomeVerification({
    required this.id,
    required this.ingresoPlanificadoId,
    required this.fechaEsperada,
    required this.fechaReal,
    required this.montoReal,
    this.transaccionId,
  });

  final int id;
  final int ingresoPlanificadoId;
  final String fechaEsperada;
  final String fechaReal;
  final double montoReal;
  final int? transaccionId;

  factory IncomeVerification.fromJson(Map<String, dynamic> json) =>
      IncomeVerification(
        id: asInt(json['id']),
        ingresoPlanificadoId: asInt(json['ingreso_planificado_id']),
        fechaEsperada: AppDate.normalize(json['fecha_esperada']),
        fechaReal: AppDate.normalize(json['fecha_real']),
        montoReal: asDouble(json['monto_real']),
        transaccionId: asIntOrNull(json['transaccion_id']),
      );
}

/// Una fecha concreta en la que se espera (o ya llegó) un ingreso planificado.
///
/// No existe en la base de datos: se calcula en el cliente a partir del plan y
/// las verificaciones, igual que `generateMonthlyOccurrences` en la web.
class PlannedOccurrence {
  const PlannedOccurrence({
    required this.plan,
    required this.fechaEsperada,
    this.verification,
  });

  final PlannedIncome plan;
  final String fechaEsperada;
  final IncomeVerification? verification;

  bool get verificado => verification != null;
  double get monto => verification?.montoReal ?? plan.monto;
  String get descripcion => plan.descripcion;

  /// Se esperaba en una fecha ya pasada y no se ha confirmado.
  bool get isOverdue =>
      !verificado && AppDate.daysBetween(fechaEsperada, AppDate.today()) > 0;
}

/// Meta de ahorro (`finanzas_metas`).
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.nombre,
    required this.montoObjetivo,
    required this.montoActual,
    this.descripcion,
    this.fechaObjetivo,
    this.icono = 'savings',
    this.color = '#34E47E',
    this.completada = false,
  });

  final int id;
  final String nombre;
  final double montoObjetivo;
  final double montoActual;
  final String? descripcion;
  final String? fechaObjetivo;
  final String icono;
  final String color;
  final bool completada;

  /// Progreso 0-100, acotado.
  double get progress {
    if (montoObjetivo <= 0) return 0;
    return math.min(100, (montoActual / montoObjetivo) * 100);
  }

  double get remaining => math.max(0, montoObjetivo - montoActual);

  /// Días hasta la fecha objetivo; negativo si ya venció, null si no hay fecha.
  int? get daysLeft {
    if (fechaObjetivo == null || fechaObjetivo!.isEmpty) return null;
    return AppDate.daysBetween(AppDate.today(), fechaObjetivo!);
  }

  IconData get iconData => MaterialIconMap.resolve(icono);

  Color get accentColor => parseHexColor(color, fallback: const Color(0xFF34E47E));

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: asInt(json['id']),
        nombre: asString(json['nombre'], fallback: 'Meta'),
        montoObjetivo: asDouble(json['monto_objetivo']),
        montoActual: asDouble(json['monto_actual']),
        descripcion: asStringOrNull(json['descripcion']),
        fechaObjetivo: () {
          final v = AppDate.normalize(json['fecha_objetivo']);
          return v.isEmpty ? null : v;
        }(),
        icono: asString(json['icono'], fallback: 'savings'),
        color: asString(json['color'], fallback: '#34E47E'),
        completada: asBool(json['completada']),
      );
}

/// Límite de gasto por categoría y mes (`finanzas_presupuestos`).
class Budget {
  const Budget({
    required this.id,
    required this.categoria,
    required this.montoLimite,
    required this.mes,
    required this.anio,
  });

  final int id;
  final String categoria;
  final double montoLimite;
  final int mes;
  final int anio;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: asInt(json['id']),
        categoria: asString(json['categoria']),
        montoLimite: asDouble(json['monto_limite']),
        mes: asInt(json['mes']),
        anio: asInt(json['anio']),
      );
}

/// Categoría de gasto/ingreso (`finanzas_categorias`), propia de cada usuario.
class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.valor,
    required this.label,
    this.icono = 'sell',
    this.esDefault = false,
  });

  final int id;
  final String valor;
  final String label;
  final String icono;
  final bool esDefault;

  IconData get iconData => MaterialIconMap.resolve(icono);

  factory FinanceCategory.fromJson(Map<String, dynamic> json) => FinanceCategory(
        id: asInt(json['id']),
        valor: asString(json['valor']),
        label: asString(json['label']),
        icono: asString(json['icono'], fallback: 'sell'),
        esDefault: asBool(json['es_default']),
      );

  /// Fallback mientras carga el bootstrap; refleja
  /// `DEFAULT_FINANCE_CATEGORIES` del backend.
  static const List<({String valor, String label, String icono})> defaults = [
    (valor: 'comida', label: 'Comida', icono: 'restaurant'),
    (valor: 'transporte', label: 'Transporte', icono: 'directions_car'),
    (valor: 'servicios', label: 'Servicios/Facturas', icono: 'receipt_long'),
    (valor: 'entretenimiento', label: 'Entretenimiento/Ocio', icono: 'sports_esports'),
    (valor: 'salud', label: 'Salud/Bienestar', icono: 'medication'),
    (valor: 'educacion', label: 'Educación', icono: 'school'),
    (valor: 'ahorro', label: 'Ahorro/Inversión', icono: 'savings'),
    (valor: 'otros', label: 'Otros', icono: 'payments'),
  ];

  /// Color estable por categoría, para las gráficas.
  /// Los ocho valores por defecto conservan el color que tenían en la web.
  static Color colorFor(String valor, {int fallbackIndex = 0}) {
    const base = {
      'comida': Color(0xFFFF7043),
      'transporte': Color(0xFF29B6F6),
      'servicios': Color(0xFFAB47BC),
      'entretenimiento': Color(0xFFFFCA28),
      'salud': Color(0xFF26A69A),
      'educacion': Color(0xFFEC407A),
      'ahorro': Color(0xFF66BB6A),
      'arriendo': Color(0xFF8D6E63),
      'otros': Color(0xFF78909C),
    };
    final known = base[valor];
    if (known != null) return known;

    const custom = [
      Color(0xFFF06292), Color(0xFF4DD0E1), Color(0xFFAED581), Color(0xFFFFB74D),
      Color(0xFFCE93D8), Color(0xFF80DEEA), Color(0xFFFFCC02), Color(0xFFA5D6A7),
    ];
    return custom[fallbackIndex % custom.length];
  }
}

/// Convierte `#RRGGBB` (o `#AARRGGBB`) a [Color].
Color parseHexColor(String? hex, {Color fallback = const Color(0xFF34E47E)}) {
  if (hex == null || hex.isEmpty) return fallback;
  var value = hex.replaceFirst('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

/// `Color` a `#RRGGBB`, que es como lo espera la base de datos.
String toHexColor(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}
