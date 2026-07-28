import '../../core/utils/json_utils.dart';
import 'cycle.dart';
import 'event.dart';
import 'finance.dart';
import 'habit.dart';
import 'note.dart';

/// Respuesta de `/api/dashboard/bootstrap`.
///
/// Datos acotados que **no** dependen del mes. Se piden una sola vez por sesión.
class BootstrapData {
  const BootstrapData({
    this.cumpleanos = const [],
    this.cycles = const [],
    this.habits = const [],
    this.cuentas = const [],
    this.ingresosPlanificados = const [],
    this.verificaciones = const [],
    this.metas = const [],
    this.categorias = const [],
    this.categoriasUsadas = const {},
  });

  final List<Birthday> cumpleanos;
  final List<CycleLog> cycles;
  final List<Habit> habits;
  final List<Account> cuentas;
  final List<PlannedIncome> ingresosPlanificados;
  final List<IncomeVerification> verificaciones;
  final List<SavingsGoal> metas;
  final List<FinanceCategory> categorias;

  /// Categorías con movimientos o presupuestos: no se pueden borrar.
  final Set<String> categoriasUsadas;

  static const BootstrapData empty = BootstrapData();

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    final finanzas = json['finanzas'] is Map
        ? Map<String, dynamic>.from(json['finanzas'] as Map)
        : const <String, dynamic>{};

    return BootstrapData(
      cumpleanos: parseList(json['cumpleanos'], Birthday.fromJson),
      cycles: parseList(json['cycles'], CycleLog.fromJson),
      habits: parseList(json['habits'], Habit.fromJson),
      cuentas: parseList(finanzas['cuentas'], Account.fromJson),
      ingresosPlanificados:
          parseList(finanzas['ingresosPlanificados'], PlannedIncome.fromJson),
      verificaciones:
          parseList(finanzas['verificaciones'], IncomeVerification.fromJson),
      metas: parseList(finanzas['metas'], SavingsGoal.fromJson),
      categorias: parseList(finanzas['categorias'], FinanceCategory.fromJson),
      categoriasUsadas: (json['categoriasUsadas'] is List)
          ? (json['categoriasUsadas'] as List)
              .map((e) => e.toString())
              .toSet()
          : const {},
    );
  }
}

/// Respuesta de `/api/dashboard/month?mes&anio`.
///
/// Datos de alto volumen, acotados a un mes. Se recarga al cambiar de mes.
class MonthData {
  const MonthData({
    this.events = const [],
    this.transacciones = const [],
    this.notes = const [],
    this.habitLogs = const [],
    this.presupuestos = const [],
    this.transferencias = const [],
  });

  final List<CalendarEvent> events;
  final List<FinanceTransaction> transacciones;
  final List<Note> notes;
  final List<HabitLog> habitLogs;
  final List<Budget> presupuestos;
  final List<Transfer> transferencias;

  static const MonthData empty = MonthData();

  factory MonthData.fromJson(Map<String, dynamic> json) => MonthData(
        events: parseList(json['events'], CalendarEvent.fromJson),
        transacciones:
            parseList(json['transacciones'], FinanceTransaction.fromJson),
        notes: parseList(json['notes'], Note.fromJson),
        habitLogs: parseList(json['habitLogs'], HabitLog.fromJson),
        presupuestos: parseList(json['presupuestos'], Budget.fromJson),
        transferencias: parseList(json['transferencias'], Transfer.fromJson),
      );
}
