import 'package:agendaservi/app/theme/app_module.dart';
import 'package:agendaservi/app/theme/app_theme.dart';
import 'package:agendaservi/core/utils/date_utils.dart';
import 'package:agendaservi/data/models/dashboard_data.dart';
import 'package:agendaservi/data/models/event.dart';
import 'package:agendaservi/features/agenda/agenda_panel.dart';
import 'package:agendaservi/features/shell/dashboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Al tocar un día, el panel de abajo tiene que contar qué hay en ese día:
/// el festivo, quién cumple años, los eventos. Eso es lo que estos casos fijan.
class _FakeDashboard extends DashboardController {
  _FakeDashboard(this._initial);

  final DashboardState _initial;

  // Se reemplaza el build real para no disparar peticiones en el test.
  @override
  DashboardState build() => _initial;
}

void main() {
  // Las fechas se derivan de hoy: el panel filtra "próximos" contra la fecha
  // real, así que un mes fijo dejaría el test caducando solo.
  final now = DateTime.now();
  String dayOfMonth(int day) => AppDate.toKey(DateTime(now.year, now.month, day));

  // Tres días del mes distintos de hoy, para no solaparse con el evento.
  final otherDays = [1, 2, 3, 4].where((d) => d != now.day).toList();
  final holidayDate = dayOfMonth(otherDays[0]);
  final birthdayDate = dayOfMonth(otherDays[1]);
  final emptyDate = dayOfMonth(otherDays[2]);
  final eventDate = AppDate.today();

  DashboardState stateWith({String? selectedDay}) {
    return DashboardState(
      year: now.year,
      month: now.month,
      loading: false,
      selectedDay: selectedDay,
      holidays: [
        Holiday(
          date: holidayDate,
          name: 'Labour Day',
          localName: 'Día del Trabajo',
        ),
      ],
      bootstrap: BootstrapData(
        cumpleanos: [
          Birthday(
            id: 1,
            nombre: 'Ana Gómez',
            fecha: birthdayDate,
            anioNacimiento: now.year - 30,
          ),
        ],
      ),
      monthData: MonthData(
        events: [
          CalendarEvent(
            id: 7,
            titulo: 'Cita con el dentista',
            fecha: eventDate,
            hora: '09:30:00',
            ubicacion: 'Clínica Norte',
          ),
        ],
      ),
    );
  }

  Future<void> pumpPanel(WidgetTester tester, DashboardState state) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(() => _FakeDashboard(state)),
        ],
        child: MaterialApp(
          theme: AppTheme.forModule(AppModule.agenda),
          home: Scaffold(
            body: AgendaPanel(scrollController: ScrollController()),
          ),
        ),
      ),
    );
    // Las tarjetas entran escalonadas; se espera a que terminen.
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('al seleccionar un festivo, el panel lo explica', (tester) async {
    await pumpPanel(tester, stateWith(selectedDay: holidayDate));

    expect(find.text('Día del Trabajo'), findsOneWidget);
    expect(find.textContaining('Festivo nacional'), findsOneWidget);
  });

  testWidgets('al seleccionar un cumpleaños, se ve de quién es', (tester) async {
    await pumpPanel(tester, stateWith(selectedDay: birthdayDate));

    expect(find.text('Ana Gómez'), findsOneWidget);
    expect(find.text('Cumple 30 años'), findsOneWidget);
  });

  testWidgets('al seleccionar un día con evento, se ve el evento',
      (tester) async {
    await pumpPanel(tester, stateWith(selectedDay: eventDate));

    expect(find.text('Cita con el dentista'), findsOneWidget);
    expect(find.text('Clínica Norte'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('un día sin nada lo dice claramente', (tester) async {
    await pumpPanel(tester, stateWith(selectedDay: emptyDate));

    expect(find.text('Día libre'), findsOneWidget);
  });

  testWidgets('sin selección se muestra el resumen del mes, no el detalle',
      (tester) async {
    await pumpPanel(tester, stateWith());

    expect(find.text('Día libre'), findsNothing);
    expect(find.text('Ana Gómez'), findsNothing);
    // En su lugar, los próximos eventos del mes.
    expect(find.text('Próximos eventos'), findsOneWidget);
    expect(find.text('Cita con el dentista'), findsOneWidget);
  });
}
