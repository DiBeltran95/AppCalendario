import 'package:agendaservi/core/cycle/cycle_engine.dart';
import 'package:agendaservi/core/utils/date_utils.dart';
import 'package:agendaservi/data/models/cycle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Port de `frontend/src/lib/cycleUtils.test.ts`.
///
/// Estos casos son el contrato del motor: si alguno se cae, el calendario
/// estaría mostrando fases distintas a las que la usuaria ya conoce.
void main() {
  CycleLog log(String fecha, {int? id, int? sangrado}) =>
      CycleLog(id: id ?? 0, fechaInicio: fecha, diasSangrado: sangrado);

  CyclePhase? phaseOf(String date, List<CycleLog> logs) =>
      CycleEngine.detailsFor(date, CycleEngine.buildStats(logs))?.phase;

  String hoyMas(int dias) => AppDate.addDays(AppDate.today(), dias);

  group('1) Promedio con ventana móvil', () {
    test('promedia sólo los 6 ciclos recientes', () {
      final logs = [
        log('2026-01-01'), log('2026-02-15'), // 45 días (antiguo)
        log('2026-03-17'), log('2026-04-16'), log('2026-05-16'),
        log('2026-06-15'), log('2026-07-15'), log('2026-08-14'),
      ];
      final s = CycleEngine.buildStats(logs);
      expect(s.avgCycleLength, 30);
      expect(s.ciclosUsados, 6);
    });
  });

  group('2) Menos de 3 ciclos se ponderan con el estándar de 28', () {
    test('un solo ciclo de 30 -> (30 + 2*28)/3 = 29', () {
      final s = CycleEngine.buildStats([log('2026-07-01'), log('2026-06-01')]);
      expect(s.avgCycleLength, 29);
    });
  });

  group('3) Ciclos anómalos excluidos del promedio', () {
    test('el ciclo de 2 días no entra', () {
      final s = CycleEngine.buildStats(
        [log('2026-07-03'), log('2026-07-01'), log('2026-06-01')],
      );
      expect(s.ciclosUsados, 1);
    });
  });

  group('4) Fases dentro de un ciclo cerrado de 28 días', () {
    final logs = [log('2026-06-01'), log('2026-06-29')];

    test('día 1 -> period', () => expect(phaseOf('2026-06-01', logs), CyclePhase.period));
    test('día 5 -> period', () => expect(phaseOf('2026-06-05', logs), CyclePhase.period));
    test('día 6 -> follicular', () => expect(phaseOf('2026-06-06', logs), CyclePhase.follicular));
    test('día 14 -> ovulation', () => expect(phaseOf('2026-06-14', logs), CyclePhase.ovulation));
    test('día 10 -> fertile', () => expect(phaseOf('2026-06-10', logs), CyclePhase.fertile));
    test('día 20 -> luteal', () => expect(phaseOf('2026-06-20', logs), CyclePhase.luteal));
    test('día 29 -> period del ciclo siguiente',
        () => expect(phaseOf('2026-06-29', logs), CyclePhase.period));
  });

  group('5) La ovulación se recoloca al registrar un ciclo nuevo', () {
    final antes = [log('2026-06-01')];
    final despues = [log('2026-06-01'), log('2026-07-06')]; // 35 días reales

    test('antes: día 14 es ovulación',
        () => expect(phaseOf('2026-06-14', antes), CyclePhase.ovulation));
    test('después: día 14 ya no lo es',
        () => expect(phaseOf('2026-06-14', despues), CyclePhase.follicular));
    test('después: la ovulación pasa al día 21',
        () => expect(phaseOf('2026-06-21', despues), CyclePhase.ovulation));
  });

  group('6) Al eliminar un registro se recalcula hacia atrás', () {
    final con = [log('2026-06-01', id: 1), log('2026-07-06', id: 2)];
    final sin = [log('2026-06-01', id: 1)];

    test('con el registro: 2026-07-06 es period',
        () => expect(phaseOf('2026-07-06', con), CyclePhase.period));
    test('sin él: el inicio proyectado se marca como retraso',
        () => expect(phaseOf('2026-06-29', sin), CyclePhase.latePeriod));
    test('sin él: el 07-06 ya no es día 1 de nada',
        () => expect(phaseOf('2026-07-06', sin), CyclePhase.follicular));
  });

  group('7) Horizonte de proyección acotado', () {
    final logs = [log('2026-06-01')];

    test('a 1 ciclo vista sí predice',
        () => expect(phaseOf('2026-06-30', logs), isNotNull));
    test('a 3+ ciclos ya no pinta nada',
        () => expect(phaseOf('2027-06-01', logs), isNull));
    test('antes del primer registro: null',
        () => expect(phaseOf('2026-05-31', logs), isNull));
  });

  group('8) Retraso vs predicción', () {
    test('un periodo esperado ya pasado es late-period', () {
      final logs = [log(hoyMas(-40))];
      final d = CycleEngine.detailsFor(hoyMas(-11), CycleEngine.buildStats(logs));
      expect(d?.phase, CyclePhase.latePeriod);
      expect((d?.diasRetraso ?? 0) > 0, isTrue);
    });

    test('un periodo futuro es predicted-period', () {
      final d = CycleEngine.detailsFor(
        hoyMas(20),
        CycleEngine.buildStats([log(hoyMas(-8))]),
      );
      expect(d?.phase, CyclePhase.predictedPeriod);
    });
  });

  group('9) Sin desfase de zona horaria en "hoy"', () {
    test('el día de hoy se titula "Hoy"', () {
      final hoy = AppDate.today();
      final d = CycleEngine.detailsFor(hoy, CycleEngine.buildStats([log(hoy)]));
      expect(d?.dateTitle.startsWith('Hoy es el día 1'), isTrue);
      expect(d?.esCicloObservado, isTrue);
    });
  });

  group('10) Robustez ante datos sucios', () {
    test('lista vacía', () {
      expect(CycleEngine.detailsFor('2026-06-01', CycleEngine.buildStats([])), isNull);
    });

    test('null', () {
      expect(CycleEngine.detailsFor('2026-06-01', CycleEngine.buildStats(null)), isNull);
    });

    test('registros inválidos se descartan', () {
      final s = CycleEngine.buildStats([const CycleLog(id: 0, fechaInicio: 'basura')]);
      expect(s.logs, isEmpty);
    });

    test('un duplicado exacto no produce NaN ni progreso absurdo', () {
      final d = CycleEngine.detailsFor(
        '2026-06-03',
        CycleEngine.buildStats([log('2026-06-01', id: 1), log('2026-06-01', id: 2)]),
      );
      expect(d, isNotNull);
      expect(d!.progressPercent.isFinite, isTrue);
      expect(d.progressPercent <= 100, isTrue);
    });

    test('un registro futuro heredado no rompe el cálculo', () {
      final d = CycleEngine.detailsFor(
        '2026-08-01',
        CycleEngine.buildStats([log('2026-07-01'), log('2030-01-01')]),
      );
      expect(d, isNotNull);
      expect(d!.dayInCurrentCycle.isFinite, isTrue);
    });
  });

  group('11) Historial', () {
    final h = CycleEngine.history([
      log('2026-06-01', id: 1),
      log('2026-07-06', id: 2),
      log('2026-07-08', id: 3),
    ]);

    test('ordena del más reciente al más antiguo', () {
      expect(
        h.map((e) => e.fechaInicio).toList(),
        ['2026-07-08', '2026-07-06', '2026-06-01'],
      );
    });
    test('el más reciente está en curso', () => expect(h[0].enCurso, isTrue));
    test('el más reciente no tiene duración aún', () => expect(h[0].duracion, isNull));
    test('duración del ciclo del 06-01 = 35 días', () => expect(h[2].duracion, 35));
    test('marca el ciclo de 2 días como atípico', () => expect(h[1].anomalo, isTrue));
  });

  group('12) Días de sangrado por ciclo', () {
    test('un sangrado de 3 días acorta la fase de menstruación', () {
      final corto = [log('2026-06-01', sangrado: 3), log('2026-06-29')];
      expect(phaseOf('2026-06-03', corto), CyclePhase.period);
      expect(phaseOf('2026-06-04', corto), CyclePhase.follicular);
    });

    test('un sangrado de 7 días llega hasta el día 7', () {
      final largo = [log('2026-06-01', sangrado: 7), log('2026-06-29')];
      expect(phaseOf('2026-06-07', largo), CyclePhase.period);
    });

    test('un ciclo sin dato usa el promedio de la usuaria', () {
      final mixto = [
        log('2026-08-03'),
        log('2026-07-06', sangrado: 7),
        log('2026-06-01', sangrado: 7),
      ];
      final st = CycleEngine.buildStats(mixto);
      expect(st.avgPeriodLength, 7);
      expect(st.sangradosUsados, 2);
      expect(phaseOf('2026-08-09', mixto), CyclePhase.period);

      final d = CycleEngine.detailsFor('2026-08-09', st);
      expect(d?.sangradoEstimado, isTrue);
      expect(d?.diasSangrado, 7);

      final dReal = CycleEngine.detailsFor('2026-07-06', st);
      expect(dReal?.sangradoEstimado, isFalse);
    });

    test('sin datos, 5 días por defecto', () {
      expect(CycleEngine.buildStats([log('2026-06-01')]).avgPeriodLength, 5);
    });

    test('descarta valores fuera de rango y cae al valor por defecto', () {
      final sucio = CycleEngine.buildStats([
        log('2026-06-01', sangrado: 99),
        log('2026-05-01', sangrado: -2),
      ]);
      expect(sucio.sangradosUsados, 0);
      expect(sucio.avgPeriodLength, 5);
    });

    test('el historial expone los días de sangrado o su ausencia', () {
      final h = CycleEngine.history([
        log('2026-08-03'),
        log('2026-07-06', sangrado: 7),
        log('2026-06-01', sangrado: 7),
      ]);
      expect(h.map((e) => e.diasSangrado).toList(), [null, 7, 7]);
    });
  });
}
