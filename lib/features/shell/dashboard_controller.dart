import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_module.dart';
import '../../core/cycle/cycle_engine.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/cycle.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/models/event.dart';
import '../../data/models/finance.dart';
import '../../data/models/note.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_day.dart';

/// Estado del dashboard: los datos que alimentan a los cinco módulos.
@immutable
class DashboardState {
  const DashboardState({
    required this.year,
    required this.month,
    this.bootstrap = BootstrapData.empty,
    this.monthData = MonthData.empty,
    this.holidays = const [],
    this.importantDays = const [],
    this.selectedDay,
    this.loading = true,
    this.refreshing = false,
    this.error,
  });

  /// Año visible en el calendario.
  final int year;

  /// Mes visible, 1-12.
  final int month;

  final BootstrapData bootstrap;
  final MonthData monthData;
  final List<Holiday> holidays;
  final List<ImportantDay> importantDays;

  /// Día seleccionado (`YYYY-MM-DD`), o null si no hay ninguno.
  final String? selectedDay;

  /// Primera carga, sin nada que pintar todavía.
  final bool loading;

  /// Revalidando en segundo plano con datos ya en pantalla.
  final bool refreshing;

  final String? error;

  DashboardState copyWith({
    int? year,
    int? month,
    BootstrapData? bootstrap,
    MonthData? monthData,
    List<Holiday>? holidays,
    List<ImportantDay>? importantDays,
    String? selectedDay,
    bool clearSelectedDay = false,
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) {
    return DashboardState(
      year: year ?? this.year,
      month: month ?? this.month,
      bootstrap: bootstrap ?? this.bootstrap,
      monthData: monthData ?? this.monthData,
      holidays: holidays ?? this.holidays,
      importantDays: importantDays ?? this.importantDays,
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }

  String get monthLabel => AppDate.monthLabel(year, month);

  /// Estadísticas del ciclo, calculadas una vez y reutilizadas en las ~42 celdas.
  CycleStats get cycleStats => CycleEngine.buildStats(bootstrap.cycles);

  /// Ocurrencias de ingresos planificados que caen en el mes visible.
  List<PlannedOccurrence> get occurrences =>
      _generateOccurrences(bootstrap, year, month);

  /// Movimientos del día seleccionado.
  List<FinanceTransaction> get selectedDayTransactions {
    final day = selectedDay;
    if (day == null) return const [];
    return monthData.transacciones.where((t) => t.fecha == day).toList();
  }

  /// Las ~42 celdas del mes visible, ya resueltas.
  List<CalendarDay> buildDays() {
    final total = AppDate.daysInMonth(year, month);
    final today = AppDate.today();
    final stats = cycleStats;
    final occ = occurrences;
    final totalHabits = bootstrap.habits.length;

    // Índices por fecha: recorrer las listas completas en cada celda sería
    // O(celdas × registros) y se nota en meses cargados.
    final eventsBy = <String, List<CalendarEvent>>{};
    for (final e in monthData.events) {
      (eventsBy[e.fecha] ??= []).add(e);
    }
    final txBy = <String, List<FinanceTransaction>>{};
    for (final t in monthData.transacciones) {
      (txBy[t.fecha] ??= []).add(t);
    }
    final notesBy = <String, List<Note>>{};
    for (final n in monthData.notes) {
      (notesBy[n.fecha] ??= []).add(n);
    }
    final occBy = <String, List<PlannedOccurrence>>{};
    for (final o in occ) {
      (occBy[o.fechaEsperada] ??= []).add(o);
    }
    final holidayBy = {for (final h in holidays) h.date: h};
    final importantBy = {for (final d in importantDays) d.date: d};
    // Los cumpleaños se repiten cada año: se indexan por MM-DD.
    final birthdaysBy = <String, List<Birthday>>{};
    for (final b in bootstrap.cumpleanos) {
      (birthdaysBy[b.monthDay] ??= []).add(b);
    }
    final habitsDoneBy = <String, int>{};
    for (final l in monthData.habitLogs) {
      if (l.completado) {
        habitsDoneBy[l.fecha] = (habitsDoneBy[l.fecha] ?? 0) + 1;
      }
    }

    return List.generate(total, (i) {
      final day = i + 1;
      final dateStr =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      return CalendarDay(
        day: day,
        dateStr: dateStr,
        isToday: dateStr == today,
        holiday: holidayBy[dateStr],
        importantDay: importantBy[dateStr],
        events: eventsBy[dateStr] ?? const [],
        birthdays: birthdaysBy[dateStr.substring(5)] ?? const [],
        cycle: stats.isEmpty ? null : CycleEngine.detailsFor(dateStr, stats),
        transactions: txBy[dateStr] ?? const [],
        occurrences: occBy[dateStr] ?? const [],
        notes: notesBy[dateStr] ?? const [],
        completedHabits: habitsDoneBy[dateStr] ?? 0,
        totalHabits: totalHabits,
      );
    });
  }

  /// Datos de un día concreto del mes visible.
  CalendarDay? dayFor(String? dateStr) {
    if (dateStr == null) return null;
    final days = buildDays();
    for (final d in days) {
      if (d.dateStr == dateStr) return d;
    }
    return null;
  }
}

/// Expande los ingresos planificados a las fechas concretas del mes visible.
///
/// No existe en la base de datos: se calcula en el cliente, igual que
/// `generateMonthlyOccurrences` en la web.
List<PlannedOccurrence> _generateOccurrences(
  BootstrapData data,
  int year,
  int month,
) {
  final result = <PlannedOccurrence>[];
  final monthStart = '$year-${month.toString().padLeft(2, '0')}-01';
  final monthEnd =
      '$year-${month.toString().padLeft(2, '0')}-${AppDate.daysInMonth(year, month).toString().padLeft(2, '0')}';

  for (final plan in data.ingresosPlanificados) {
    if (!plan.activo || plan.fechaInicio.isEmpty) continue;

    var cursor = plan.fechaInicio;
    // Tope defensivo: sin él, una frecuencia inesperada podría no avanzar.
    var iterations = 0;

    while (cursor.compareTo(monthEnd) <= 0 && iterations < 400) {
      iterations++;

      if (cursor.compareTo(monthStart) >= 0) {
        IncomeVerification? verification;
        for (final v in data.verificaciones) {
          if (v.ingresoPlanificadoId == plan.id && v.fechaEsperada == cursor) {
            verification = v;
            break;
          }
        }
        result.add(PlannedOccurrence(
          plan: plan,
          fechaEsperada: cursor,
          verification: verification,
        ));
      }

      final next = switch (plan.frecuencia) {
        'diario' => AppDate.addDays(cursor, 1),
        'semanal' => AppDate.addDays(cursor, 7),
        'quincenal' => AppDate.addDays(cursor, 15),
        'mensual' => _addMonths(cursor, 1),
        'bimestral' => _addMonths(cursor, 2),
        'trimestral' => _addMonths(cursor, 3),
        'semestral' => _addMonths(cursor, 6),
        'anual' => _addMonths(cursor, 12),
        _ => null, // 'unica' u otra cosa: no se repite
      };
      if (next == null) break;
      cursor = next;
    }
  }

  result.sort((a, b) => a.fechaEsperada.compareTo(b.fechaEsperada));
  return result;
}

/// Suma meses conservando el día, recortando al último día si el mes es corto
/// (un plan del día 31 cae al 28/29 en febrero).
String _addMonths(String key, int months) {
  final d = AppDate.parse(key);
  final targetMonth = d.month + months;
  final year = d.year + ((targetMonth - 1) ~/ 12);
  final month = ((targetMonth - 1) % 12) + 1;
  final lastDay = AppDate.daysInMonth(year, month);
  return AppDate.toKey(DateTime(year, month, d.day > lastDay ? lastDay : d.day));
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    final now = DateTime.now();
    final initial = DashboardState(year: now.year, month: now.month);

    // Al cambiar de usuario (o entrar por primera vez) se recarga todo.
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null && previous?.id != next.id) {
        load();
      }
    });

    Future.microtask(load);
    return initial;
  }

  int? get _userId => ref.read(currentUserProvider)?.id;

  /// Carga inicial: pinta la caché al instante y revalida contra el backend.
  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;

    final repo = ref.read(calendarRepositoryProvider);
    final year = state.year;
    final month = state.month;

    final cachedBootstrap = repo.cachedBootstrap(userId);
    final cachedMonth = repo.cachedMonth(userId, year, month);
    final hasCache = cachedBootstrap != null || cachedMonth != null;

    if (hasCache) {
      state = state.copyWith(
        bootstrap: cachedBootstrap,
        monthData: cachedMonth,
        holidays: repo.cachedHolidays(year),
        importantDays: repo.cachedImportantDays(year),
        loading: false,
        refreshing: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final results = await Future.wait([
        repo.fetchBootstrap(userId),
        repo.fetchMonth(userId, year, month),
      ]);

      state = state.copyWith(
        bootstrap: results[0] as BootstrapData,
        monthData: results[1] as MonthData,
        loading: false,
        refreshing: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        // Con datos en pantalla el error se traga: es solo una revalidación.
        error: hasCache ? null : e.message,
      );
    }

    // Festivos y días importantes van aparte: dependen del año y no deben
    // retrasar el pintado del calendario.
    unawaited(_loadYearData(year));
  }

  Future<void> _loadYearData(int year) async {
    final repo = ref.read(calendarRepositoryProvider);
    final results = await Future.wait([
      repo.fetchHolidays(year),
      repo.fetchImportantDays(year),
    ]);
    if (state.year != year) return; // el usuario ya cambió de año
    state = state.copyWith(
      holidays: results[0] as List<Holiday>,
      importantDays: results[1] as List<ImportantDay>,
    );
  }

  /// Cambia el mes visible y trae sus datos.
  Future<void> goToMonth(int year, int month) async {
    if (year == state.year && month == state.month) return;

    final userId = _userId;
    final repo = ref.read(calendarRepositoryProvider);
    final yearChanged = year != state.year;

    final cached = userId == null ? null : repo.cachedMonth(userId, year, month);

    state = state.copyWith(
      year: year,
      month: month,
      monthData: cached ?? MonthData.empty,
      refreshing: true,
      clearSelectedDay: true,
      clearError: true,
      // Si cambia el año, los festivos del anterior ya no aplican.
      holidays: yearChanged ? repo.cachedHolidays(year) : null,
      importantDays: yearChanged ? repo.cachedImportantDays(year) : null,
    );

    if (userId == null) return;

    try {
      final data = await repo.fetchMonth(userId, year, month);
      if (state.year != year || state.month != month) return;
      state = state.copyWith(monthData: data, refreshing: false);
    } on ApiException catch (e) {
      if (state.year != year || state.month != month) return;
      state = state.copyWith(
        refreshing: false,
        error: cached == null ? e.message : null,
      );
    }

    if (yearChanged) unawaited(_loadYearData(year));
  }

  void goToPreviousMonth() {
    final m = state.month == 1 ? 12 : state.month - 1;
    final y = state.month == 1 ? state.year - 1 : state.year;
    goToMonth(y, m);
  }

  void goToNextMonth() {
    final m = state.month == 12 ? 1 : state.month + 1;
    final y = state.month == 12 ? state.year + 1 : state.year;
    goToMonth(y, m);
  }

  /// Vuelve al mes actual y selecciona hoy.
  Future<void> goToToday() async {
    final now = DateTime.now();
    await goToMonth(now.year, now.month);
    state = state.copyWith(selectedDay: AppDate.today());
  }

  void selectDay(String? dateStr) {
    if (dateStr == null || dateStr == state.selectedDay) {
      state = state.copyWith(clearSelectedDay: true);
    } else {
      state = state.copyWith(selectedDay: dateStr);
    }
  }

  void clearSelection() => state = state.copyWith(clearSelectedDay: true);

  /// Recarga bootstrap y mes visible. Se llama tras cada escritura.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(refreshing: true);
    final repo = ref.read(calendarRepositoryProvider);

    try {
      final results = await Future.wait([
        repo.fetchBootstrap(userId),
        repo.fetchMonth(userId, state.year, state.month),
      ]);
      state = state.copyWith(
        bootstrap: results[0] as BootstrapData,
        monthData: results[1] as MonthData,
        loading: false,
        refreshing: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(refreshing: false, error: e.message);
    }
  }

  /// Solo el mes visible: más barato tras editar una nota o marcar un hábito.
  Future<void> refreshMonth() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final data = await ref
          .read(calendarRepositoryProvider)
          .fetchMonth(userId, state.year, state.month);
      state = state.copyWith(monthData: data, refreshing: false);
    } on ApiException {
      state = state.copyWith(refreshing: false);
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);

/// Módulo activo. Vive fuera del dashboard porque también decide el tema.
final activeModuleProvider = NotifierProvider<ActiveModuleController, AppModule>(
  ActiveModuleController.new,
);

class ActiveModuleController extends Notifier<AppModule> {
  @override
  AppModule build() => AppModule.agenda;

  void select(AppModule module) => state = module;
}
