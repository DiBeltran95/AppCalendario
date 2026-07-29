import 'package:agendaservi/app/theme/app_module.dart';
import 'package:agendaservi/core/utils/date_utils.dart';
import 'package:agendaservi/data/models/event.dart';
import 'package:agendaservi/data/models/finance.dart';
import 'package:agendaservi/data/models/note.dart';
import 'package:agendaservi/features/calendar/calendar_day.dart';
import 'package:agendaservi/features/calendar/day_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El punto de este rediseño es que el calendario diga **quién** y **qué**,
/// no que pinte puntos. Estos casos fijan justo eso.
void main() {
  const accent = Color(0xFF25D366);
  final hoy = AppDate.today();
  final manana = AppDate.addDays(hoy, 1);

  CalendarDay day({
    String? date,
    List<Birthday> birthdays = const [],
    List<CalendarEvent> events = const [],
    Holiday? holiday,
    ImportantDay? importantDay,
    List<FinanceTransaction> transactions = const [],
    List<PlannedOccurrence> occurrences = const [],
    List<Note> notes = const [],
    int completedHabits = 0,
    int totalHabits = 0,
  }) {
    return CalendarDay(
      day: 15,
      dateStr: date ?? manana,
      isToday: false,
      birthdays: birthdays,
      events: events,
      holiday: holiday,
      importantDay: importantDay,
      transactions: transactions,
      occurrences: occurrences,
      notes: notes,
      completedHabits: completedHabits,
      totalHabits: totalHabits,
    );
  }

  CalendarEvent event({
    required String titulo,
    String? hora,
    TxKind tipo = TxKind.none,
    double costo = 0,
    String estado = 'pendiente',
  }) {
    return CalendarEvent(
      id: 1,
      titulo: titulo,
      fecha: manana,
      hora: hora,
      tipoTransaccion: tipo,
      costo: costo,
      estadoPago: estado,
    );
  }

  group('Etiquetas de celda: se ve quién y qué', () {
    test('un cumpleaños muestra el primer nombre, no un punto', () {
      final chips = DayContent.chipsFor(
        day(birthdays: [
          const Birthday(id: 1, nombre: 'Ana Gómez', fecha: '1996-05-15'),
        ]),
        AppModule.agenda,
        accent,
      );

      expect(chips, isNotEmpty);
      expect(chips.first.label, 'Ana');
      expect(chips.first.emoji, '🎂');
    });

    test('un festivo muestra su nombre', () {
      final chips = DayContent.chipsFor(
        day(holiday: const Holiday(date: '2026-05-15', name: 'Ascensión')),
        AppModule.agenda,
        accent,
      );

      expect(chips.any((c) => c.label.startsWith('Ascen')), isTrue);
    });

    test('un evento con hora muestra hora y título', () {
      final chips = DayContent.chipsFor(
        day(events: [event(titulo: 'Reunión', hora: '08:30:00')]),
        AppModule.agenda,
        accent,
      );

      expect(chips.first.label, startsWith('08:30'));
    });

    test('los títulos largos se recortan sin desbordar la celda', () {
      final chips = DayContent.chipsFor(
        day(events: [event(titulo: 'Cita con el especialista de rodilla')]),
        AppModule.agenda,
        accent,
      );

      expect(chips.first.label.length, lessThanOrEqualTo(9));
      expect(chips.first.label, endsWith('…'));
    });

    test('finanzas muestra importes, no un icono genérico', () {
      final chips = DayContent.chipsFor(
        day(transactions: [
          FinanceTransaction(
            id: 1,
            tipo: 'ingreso',
            monto: 2500000,
            descripcion: 'Nómina',
            fecha: manana,
          ),
          FinanceTransaction(
            id: 2,
            tipo: 'gasto',
            monto: 150000,
            descripcion: 'Mercado',
            fecha: manana,
          ),
        ]),
        AppModule.finance,
        accent,
      );

      expect(chips.any((c) => c.label.startsWith('+')), isTrue);
      expect(chips.any((c) => c.label.startsWith('-')), isTrue);
    });

    test('notas muestra el texto de la nota', () {
      final chips = DayContent.chipsFor(
        day(notes: [
          const Note(id: 1, fecha: '2026-05-15', contenido: 'Llamar al banco'),
        ]),
        AppModule.notes,
        accent,
      );

      expect(chips.first.label, startsWith('Llamar'));
    });

    test('hábitos muestra el avance del día', () {
      final chips = DayContent.chipsFor(
        day(completedHabits: 3, totalHabits: 4),
        AppModule.habits,
        accent,
      );

      expect(chips.first.label, '3/4');
    });

    test('un día vacío no genera etiquetas', () {
      expect(DayContent.chipsFor(day(), AppModule.agenda, accent), isEmpty);
    });
  });

  group('Resumen del mes: nombre completo y contexto', () {
    test('el cumpleaños dice el nombre completo y la edad', () {
      final year = AppDate.parse(manana).year;
      final highlights = DayContent.highlightsFor(
        [
          day(birthdays: [
            Birthday(
              id: 1,
              nombre: 'Ana Gómez',
              fecha: manana,
              anioNacimiento: year - 28,
            ),
          ]),
        ],
        AppModule.agenda,
        accent,
      );

      expect(highlights.single.title, 'Ana Gómez');
      expect(highlights.single.subtitle, 'Cumple 28 años');
    });

    test('el festivo se explica', () {
      final highlights = DayContent.highlightsFor(
        [
          day(holiday: Holiday(date: manana, name: 'Día de la Raza')),
        ],
        AppModule.agenda,
        accent,
      );

      expect(highlights.single.title, 'Día de la Raza');
      expect(highlights.single.subtitle, contains('Festivo'));
    });

    test('lo ya pasado no aparece en "lo que viene"', () {
      final ayer = AppDate.addDays(hoy, -1);
      final highlights = DayContent.highlightsFor(
        [
          day(
            date: ayer,
            birthdays: [Birthday(id: 1, nombre: 'Pasado', fecha: ayer)],
          ),
        ],
        AppModule.agenda,
        accent,
      );

      expect(highlights, isEmpty);
    });

    test('con onlyUpcoming en false sí se ve el mes completo', () {
      final ayer = AppDate.addDays(hoy, -1);
      final highlights = DayContent.highlightsFor(
        [
          day(
            date: ayer,
            birthdays: [Birthday(id: 1, nombre: 'Pasado', fecha: ayer)],
          ),
        ],
        AppModule.agenda,
        accent,
        onlyUpcoming: false,
      );

      expect(highlights.single.title, 'Pasado');
    });

    test('los cumpleaños pesan más que los eventos del mismo día', () {
      final highlights = DayContent.highlightsFor(
        [
          day(
            birthdays: [Birthday(id: 1, nombre: 'Ana Gómez', fecha: manana)],
            events: [event(titulo: 'Reunión')],
          ),
        ],
        AppModule.agenda,
        accent,
      );

      expect(highlights.first.title, 'Ana Gómez');
    });

    test('finanzas destaca el pendiente con su importe', () {
      final highlights = DayContent.highlightsFor(
        [
          day(events: [
            event(
              titulo: 'Arriendo',
              tipo: TxKind.expense,
              costo: 1200000,
            ),
          ]),
        ],
        AppModule.finance,
        accent,
      );

      expect(highlights.single.title, 'Arriendo');
      expect(highlights.single.subtitle, 'Pago pendiente');
      expect(highlights.single.trailing, isNotNull);
    });

    test('todo queda ordenado por fecha', () {
      final pasadoManana = AppDate.addDays(hoy, 2);
      final highlights = DayContent.highlightsFor(
        [
          day(
            date: pasadoManana,
            birthdays: [Birthday(id: 2, nombre: 'Segundo', fecha: pasadoManana)],
          ),
          day(birthdays: [Birthday(id: 1, nombre: 'Primero', fecha: manana)]),
        ],
        AppModule.agenda,
        accent,
      );

      expect(highlights.map((h) => h.title).toList(), ['Primero', 'Segundo']);
    });
  });
}
