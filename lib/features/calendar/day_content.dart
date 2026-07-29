import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../core/utils/date_utils.dart';
import 'calendar_day.dart';

/// Una etiqueta con contenido real dentro de una celda del calendario.
///
/// La versión web solo pintaba puntos y emojis: había que tocar el día para
/// enterarse de algo. Aquí cada celda dice **qué** y **quién**, como el mes de
/// Google Calendar.
class DayChip {
  const DayChip({
    required this.label,
    required this.color,
    this.emoji,
    this.filled = false,
  });

  /// Texto corto ya recortado para el ancho de una celda.
  final String label;

  final Color color;

  /// Emoji antepuesto, cuando aporta más que un icono.
  final String? emoji;

  /// Fondo sólido en vez de tinte suave; se reserva para lo más importante
  /// del día (un festivo, la menstruación).
  final bool filled;
}

/// Resumen "de verdad" de un día: lo que se muestra en la tarjeta de resumen
/// del mes, con nombres completos y contexto.
class DayHighlight {
  const DayHighlight({
    required this.dateStr,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.emoji,
    this.trailing,
    this.priority = 0,
  });

  final String dateStr;

  /// Quién o qué: "Ana Gómez", "Día de la Raza", "Arriendo".
  final String title;

  /// Contexto: "Cumple 28 años", "Festivo nacional", "8:30 a. m.".
  final String subtitle;

  final Color color;
  final IconData icon;
  final String? emoji;

  /// Texto a la derecha (importe, racha…).
  final String? trailing;

  /// Mayor gana al ordenar; empata por fecha.
  final int priority;
}

/// Construye el contenido visible de las celdas y del resumen del mes.
abstract final class DayContent {
  /// Cuántos caracteres caben cómodamente en una etiqueta de celda.
  static const int _maxChipChars = 9;

  static String _trim(String value, [int max = _maxChipChars]) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 1)}…';
  }

  /// Primer nombre, que es lo que cabe y lo que identifica.
  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  // -------------------------------------------------------------------------
  // Etiquetas de celda
  // -------------------------------------------------------------------------

  /// Hasta dos etiquetas por celda; la tercera se resume como "+N".
  static List<DayChip> chipsFor(CalendarDay day, AppModule module, Color accent) {
    return switch (module) {
      AppModule.agenda => _agendaChips(day, accent),
      AppModule.finance => _financeChips(day),
      AppModule.cycle => _cycleChips(day),
      AppModule.notes => _notesChips(day, accent),
      AppModule.habits => _habitsChips(day, accent),
    };
  }

  static List<DayChip> _agendaChips(CalendarDay day, Color accent) {
    final chips = <DayChip>[];

    // Los cumpleaños van primero: son el dato que más se busca de un vistazo.
    for (final birthday in day.birthdays) {
      chips.add(DayChip(
        label: _trim(_firstName(birthday.nombre), 7),
        color: const Color(0xFFF06292),
        emoji: '🎂',
      ));
    }

    if (day.holiday != null) {
      chips.add(DayChip(
        label: _trim(day.holiday!.displayName, 8),
        color: AppColors.danger,
        emoji: '🎉',
        filled: true,
      ));
    }

    if (day.importantDay != null) {
      chips.add(DayChip(
        label: _trim(day.importantDay!.nombre, 8),
        color: AppColors.gold,
        emoji: '★',
      ));
    }

    for (final event in day.events) {
      final time = event.shortTime;
      chips.add(DayChip(
        label: _trim(
          time == null ? event.titulo : '$time ${event.titulo}',
        ),
        color: event.isFinancial
            ? (event.tipoTransaccion.value == 'ingreso'
                ? AppColors.income
                : AppColors.expense)
            : accent,
      ));
    }

    return chips;
  }

  static List<DayChip> _financeChips(CalendarDay day) {
    final chips = <DayChip>[];

    final income = day.incomeTotal;
    final expense = day.expenseTotal;

    if (income > 0) {
      chips.add(DayChip(
        label: '+${AppCurrency.compact(income)}',
        color: AppColors.income,
      ));
    }
    if (expense > 0) {
      chips.add(DayChip(
        label: '-${AppCurrency.compact(expense)}',
        color: AppColors.expense,
      ));
    }

    // Cobros planificados que aún no se confirman.
    final pending = day.occurrences.where((o) => !o.verificado).toList();
    if (pending.isNotEmpty) {
      chips.add(DayChip(
        label: _trim(pending.first.descripcion, 8),
        color: AppColors.warning,
        emoji: '⏳',
      ));
    }

    // Eventos con costo que siguen pendientes de pago.
    for (final event in day.financialEvents.where((e) => e.isPending)) {
      chips.add(DayChip(
        label: _trim(event.titulo, 8),
        color: AppColors.warning,
      ));
    }

    return chips;
  }

  static List<DayChip> _cycleChips(CalendarDay day) {
    final phase = day.cycle?.phase;
    if (phase == null) return const [];

    // En menstruación y ovulación la propia celda ya va pintada: la etiqueta
    // sería redundante y quitaría aire.
    return switch (phase.key) {
      'period' => [
          DayChip(label: 'Día ${day.cycle!.dayInCurrentCycle}',
              color: Colors.white, filled: true),
        ],
      'ovulation' => [
          const DayChip(label: 'Ovulación', color: Colors.white, filled: true),
        ],
      'fertile' => [
          const DayChip(label: 'Fértil', color: AppColors.phaseFertile),
        ],
      'late-period' => [
          DayChip(
            label: '+${day.cycle!.diasRetraso}d',
            color: AppColors.phaseLate,
            emoji: '⏳',
          ),
        ],
      'predicted-period' => [
          const DayChip(label: 'Previsto', color: AppColors.phasePeriod),
        ],
      _ => const [],
    };
  }

  static List<DayChip> _notesChips(CalendarDay day, Color accent) {
    return [
      for (final note in day.notes)
        DayChip(label: _trim(note.preview, 10), color: note.accentColor),
    ];
  }

  static List<DayChip> _habitsChips(CalendarDay day, Color accent) {
    if (day.totalHabits == 0) return const [];
    final complete = day.completedHabits == day.totalHabits;
    return [
      DayChip(
        label: '${day.completedHabits}/${day.totalHabits}',
        color: complete ? AppColors.gold : accent,
        emoji: complete ? '🔥' : null,
        filled: complete,
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Resumen del mes
  // -------------------------------------------------------------------------

  /// Todo lo relevante del mes, con nombres completos, ordenado por fecha.
  ///
  /// Es la respuesta a "¿qué hay este mes?" sin tener que ir día por día.
  static List<DayHighlight> highlightsFor(
    List<CalendarDay> days,
    AppModule module,
    Color accent, {
    bool onlyUpcoming = true,
  }) {
    final today = AppDate.today();
    final result = <DayHighlight>[];

    for (final day in days) {
      // Lo ya pasado se oculta salvo que se pida el mes completo.
      if (onlyUpcoming && day.dateStr.compareTo(today) < 0) continue;

      switch (module) {
        case AppModule.agenda:
          _agendaHighlights(day, accent, result);
        case AppModule.finance:
          _financeHighlights(day, result);
        case AppModule.cycle:
          _cycleHighlights(day, result);
        case AppModule.notes:
          _notesHighlights(day, result);
        case AppModule.habits:
          _habitsHighlights(day, accent, result);
      }
    }

    result.sort((a, b) {
      final byDate = a.dateStr.compareTo(b.dateStr);
      if (byDate != 0) return byDate;
      return b.priority.compareTo(a.priority);
    });
    return result;
  }

  static void _agendaHighlights(
    CalendarDay day,
    Color accent,
    List<DayHighlight> out,
  ) {
    final year = AppDate.parse(day.dateStr).year;

    for (final birthday in day.birthdays) {
      final age = birthday.ageOn(year);
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: birthday.nombre,
        subtitle: age == null ? 'Cumpleaños' : 'Cumple $age años',
        color: const Color(0xFFF06292),
        icon: Icons.cake_rounded,
        emoji: '🎂',
        priority: 3,
      ));
    }

    if (day.holiday != null) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: day.holiday!.displayName,
        subtitle: 'Festivo nacional · día no laboral',
        color: AppColors.danger,
        icon: Icons.celebration_rounded,
        emoji: '🎉',
        priority: 2,
      ));
    }

    if (day.importantDay != null) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: day.importantDay!.nombre,
        subtitle: day.importantDay!.descripcion ??
            day.importantDay!.categoria ??
            'Día especial',
        color: AppColors.gold,
        icon: Icons.star_rounded,
        emoji: '★',
        priority: 1,
      ));
    }

    for (final event in day.events) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: event.titulo,
        subtitle: [
          event.shortTime ?? 'Todo el día',
          if (event.ubicacion.isNotEmpty) event.ubicacion,
        ].join(' · '),
        color: event.isFinancial
            ? (event.tipoTransaccion.value == 'ingreso'
                ? AppColors.income
                : AppColors.expense)
            : accent,
        icon: Icons.event_rounded,
        trailing: event.isFinancial && event.costo > 0
            ? AppCurrency.compact(event.costo)
            : null,
      ));
    }
  }

  static void _financeHighlights(CalendarDay day, List<DayHighlight> out) {
    for (final occurrence in day.occurrences.where((o) => !o.verificado)) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: occurrence.descripcion,
        subtitle: occurrence.isOverdue
            ? 'Ingreso atrasado · sin verificar'
            : 'Ingreso planificado (${occurrence.plan.frecuencia})',
        color: occurrence.isOverdue ? AppColors.danger : AppColors.warning,
        icon: Icons.schedule_rounded,
        trailing: AppCurrency.compact(occurrence.monto),
        priority: 3,
      ));
    }

    for (final event in day.financialEvents.where((e) => e.isPending)) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: event.titulo,
        subtitle: event.tipoTransaccion.value == 'ingreso'
            ? 'Cobro pendiente'
            : 'Pago pendiente',
        color: AppColors.warning,
        icon: Icons.pending_actions_rounded,
        trailing: AppCurrency.compact(event.costo),
        priority: 2,
      ));
    }

    for (final tx in day.transactions) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: tx.descripcion,
        subtitle: tx.isIncome ? 'Ingreso · ${tx.categoria}' : 'Gasto · ${tx.categoria}',
        color: tx.isIncome ? AppColors.income : AppColors.expense,
        icon: tx.isIncome
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        trailing: AppCurrency.signed(tx.monto, isIncome: tx.isIncome),
      ));
    }
  }

  static void _cycleHighlights(CalendarDay day, List<DayHighlight> out) {
    final cycle = day.cycle;
    if (cycle == null) return;

    // Solo los hitos: el primer día de cada fase relevante.
    final isMilestone = switch (cycle.phase.key) {
      'ovulation' => true,
      'period' || 'predicted-period' => cycle.dayInCurrentCycle == 1,
      'fertile' => cycle.dayInCurrentCycle == cycle.actualCycleLength - 19,
      'late-period' => cycle.diasRetraso > 0 && cycle.dayInCurrentCycle == 1,
      _ => false,
    };
    if (!isMilestone) return;

    out.add(DayHighlight(
      dateStr: day.dateStr,
      title: cycle.phase.label,
      subtitle: switch (cycle.phase.key) {
        'ovulation' => 'Fertilidad máxima',
        'period' => 'Inicio del periodo · día 1',
        'predicted-period' => 'Periodo previsto',
        'late-period' => '${cycle.diasRetraso} días de retraso',
        _ => 'Inicio de la ventana fértil',
      },
      color: cycle.phase.color,
      icon: Icons.water_drop_rounded,
      emoji: cycle.phase.badge,
      priority: 2,
    ));
  }

  static void _notesHighlights(CalendarDay day, List<DayHighlight> out) {
    for (final note in day.notes) {
      out.add(DayHighlight(
        dateStr: day.dateStr,
        title: note.preview,
        subtitle: note.etiqueta,
        color: note.accentColor,
        icon: Icons.edit_note_rounded,
      ));
    }
  }

  static void _habitsHighlights(
    CalendarDay day,
    Color accent,
    List<DayHighlight> out,
  ) {
    if (day.totalHabits == 0) return;
    // Solo se destacan los días redondos: reconocer el logro, no listar todo.
    if (day.completedHabits != day.totalHabits) return;

    out.add(DayHighlight(
      dateStr: day.dateStr,
      title: 'Día completo',
      subtitle: '${day.totalHabits} de ${day.totalHabits} hábitos cumplidos',
      color: AppColors.gold,
      icon: Icons.local_fire_department_rounded,
      emoji: '🔥',
      priority: 1,
    ));
  }
}
