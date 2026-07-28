import '../../data/models/cycle.dart';
import '../../data/models/event.dart';
import '../../data/models/finance.dart';
import '../../data/models/note.dart';

/// Todo lo que una celda del calendario necesita saber sobre su día.
///
/// Se calcula una vez por mes (no por celda ni por build), igual que el
/// `renderCalendar()` de la versión web.
class CalendarDay {
  const CalendarDay({
    required this.day,
    required this.dateStr,
    required this.isToday,
    this.holiday,
    this.importantDay,
    this.events = const [],
    this.birthdays = const [],
    this.cycle,
    this.transactions = const [],
    this.occurrences = const [],
    this.notes = const [],
    this.completedHabits = 0,
    this.totalHabits = 0,
  });

  final int day;

  /// `YYYY-MM-DD`.
  final String dateStr;

  final bool isToday;
  final Holiday? holiday;
  final ImportantDay? importantDay;
  final List<CalendarEvent> events;
  final List<Birthday> birthdays;
  final CycleDetails? cycle;
  final List<FinanceTransaction> transactions;
  final List<PlannedOccurrence> occurrences;
  final List<Note> notes;
  final int completedHabits;
  final int totalHabits;

  // --- Derivados por módulo ---

  bool get hasEvents => events.isNotEmpty;
  bool get hasBirthdays => birthdays.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;

  /// Eventos que además son un movimiento de dinero.
  List<CalendarEvent> get financialEvents =>
      events.where((e) => e.isFinancial).toList();

  /// Eventos "normales", sin componente financiera.
  List<CalendarEvent> get generalEvents =>
      events.where((e) => !e.isFinancial).toList();

  bool get hasFinance =>
      financialEvents.isNotEmpty ||
      transactions.isNotEmpty ||
      occurrences.isNotEmpty;

  /// Hay algo de dinero sin confirmar en este día.
  bool get hasPendingFinance =>
      financialEvents.any((e) => e.isPending) ||
      occurrences.any((o) => !o.verificado);

  /// Suma de todo lo que se mueve ese día, para el badge del calendario.
  double get financeTotal {
    var total = 0.0;
    for (final e in financialEvents) {
      total += e.costo;
    }
    for (final t in transactions) {
      total += t.monto;
    }
    for (final o in occurrences) {
      if (!o.verificado) total += o.monto;
    }
    return total;
  }

  double get incomeTotal => transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, t) => sum + t.monto);

  double get expenseTotal => transactions
      .where((t) => t.isExpense)
      .fold(0.0, (sum, t) => sum + t.monto);

  double get balance => incomeTotal - expenseTotal;

  /// Proporción de hábitos completados, 0..1.
  double get habitCompletion =>
      totalHabits > 0 ? completedHabits / totalHabits : 0;

  /// Nivel del heatmap de hábitos, 0..4, igual que las clases `habit-heat-N`.
  int get habitHeatLevel {
    if (totalHabits == 0) return -1;
    final rate = habitCompletion;
    if (rate == 0) return 0;
    if (rate <= 0.33) return 1;
    if (rate <= 0.66) return 2;
    if (rate < 1) return 3;
    return 4;
  }

  /// El día no tiene absolutamente nada en ningún módulo.
  bool get isEmpty =>
      !hasEvents &&
      !hasBirthdays &&
      !hasNotes &&
      !hasFinance &&
      holiday == null &&
      importantDay == null;
}
