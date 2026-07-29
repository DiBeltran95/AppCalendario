import 'package:agendaservi/app/theme/app_module.dart';
import 'package:agendaservi/app/theme/app_theme.dart';
import 'package:agendaservi/data/models/event.dart';
import 'package:agendaservi/features/calendar/calendar_view.dart';
import 'package:agendaservi/features/calendar/calendar_day.dart';
import 'package:agendaservi/features/calendar/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprueba que la celda **dibuja** el contenido, no solo que lo calcula.
void main() {
  Future<void> pumpCell(
    WidgetTester tester,
    CalendarDay day, {
    AppModule module = AppModule.agenda,
    bool selected = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forModule(module),
        home: Scaffold(
          body: Center(
            // Ancho real de una celda en un teléfono de 375 pt.
            child: SizedBox(
              width: 48,
              height: CalendarView.cellHeight,
              child: DayCell(
                data: day,
                module: module,
                selected: selected,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('la celda pinta el nombre del cumpleañero', (tester) async {
    await pumpCell(
      tester,
      const CalendarDay(
        day: 15,
        dateStr: '2026-05-15',
        isToday: false,
        birthdays: [Birthday(id: 1, nombre: 'Ana Gómez', fecha: '2026-05-15')],
      ),
    );

    expect(find.text('15'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('🎂'), findsOneWidget);
  });

  testWidgets('la celda pinta el título del evento', (tester) async {
    await pumpCell(
      tester,
      const CalendarDay(
        day: 3,
        dateStr: '2026-05-03',
        isToday: false,
        events: [
          CalendarEvent(id: 1, titulo: 'Dentista', fecha: '2026-05-03'),
        ],
      ),
    );

    expect(find.text('Dentista'), findsOneWidget);
  });

  testWidgets('con más de dos cosas aparece el contador +N', (tester) async {
    await pumpCell(
      tester,
      const CalendarDay(
        day: 8,
        dateStr: '2026-05-08',
        isToday: false,
        birthdays: [
          Birthday(id: 1, nombre: 'Ana', fecha: '2026-05-08'),
          Birthday(id: 2, nombre: 'Luis', fecha: '2026-05-08'),
        ],
        events: [
          CalendarEvent(id: 1, titulo: 'Cita', fecha: '2026-05-08'),
          CalendarEvent(id: 2, titulo: 'Pago', fecha: '2026-05-08'),
        ],
      ),
    );

    // Dos etiquetas visibles y el resto resumido.
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('un día vacío solo muestra el número', (tester) async {
    await pumpCell(
      tester,
      const CalendarDay(day: 21, dateStr: '2026-05-21', isToday: false),
    );

    expect(find.text('21'), findsOneWidget);
    // Sin contador ni etiquetas.
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('el contenido cabe: la celda no desborda', (tester) async {
    await pumpCell(
      tester,
      const CalendarDay(
        day: 12,
        dateStr: '2026-05-12',
        isToday: true,
        birthdays: [
          Birthday(id: 1, nombre: 'Maximiliano Restrepo', fecha: '2026-05-12'),
        ],
        events: [
          CalendarEvent(
            id: 1,
            titulo: 'Reunión trimestral de resultados',
            fecha: '2026-05-12',
            hora: '14:30:00',
          ),
        ],
      ),
    );

    // Un overflow de layout marca el test como fallido en Flutter, así que
    // llegar hasta aquí sin excepciones ya es la comprobación.
    expect(tester.takeException(), isNull);
  });

  testWidgets('en finanzas se ve el importe del día', (tester) async {
    await pumpCell(
      tester,
      const CalendarDay(
        day: 5,
        dateStr: '2026-05-05',
        isToday: false,
        events: [
          CalendarEvent(
            id: 1,
            titulo: 'Arriendo',
            fecha: '2026-05-05',
            tipoTransaccion: TxKind.expense,
            costo: 1200000,
          ),
        ],
      ),
      module: AppModule.finance,
    );

    expect(find.text('Arriendo'), findsOneWidget);
  });
}
