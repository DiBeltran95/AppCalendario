import 'dart:math' as math;

import '../../data/models/cycle.dart';
import '../utils/date_utils.dart';

/// Motor de cálculo del ciclo menstrual.
///
/// Port 1:1 de `frontend/src/lib/cycleUtils.ts`. Se mantiene la misma lógica
/// porque los datos ya existen en producción y cualquier desviación cambiaría
/// lo que la usuaria ve para registros que ya tiene guardados.
///
/// Modelo:
///  - Cada registro del usuario es el DÍA 1 de un ciclo.
///  - Entre dos registros consecutivos la duración es un **hecho observado**,
///    no una estimación: se usa tal cual para situar la ovulación (14 días
///    antes del siguiente sangrado).
///  - Después del último registro ya no hay dato, así que se **proyecta** con
///    el promedio de los ciclos recientes. La proyección se corta a dos ciclos:
///    más allá no tiene valor clínico y pintarla engaña.
abstract final class CycleEngine {
  /// Solo se promedian ciclos dentro de este rango; fuera son anomalías.
  static const int minCicloValido = 20;
  static const int maxCicloValido = 45;

  /// Cuántos ciclos recientes entran en el promedio (ventana móvil).
  static const int ventanaCiclos = 6;

  /// Cuántos ciclos se proyectan hacia adelante tras el último registro.
  static const int maxCiclosProyectados = 2;

  /// Duración de referencia cuando aún no hay histórico suficiente.
  static const int cicloEstandar = 28;

  /// Piso defensivo: evita módulos y divisiones por valores absurdos.
  static const int cicloMinimo = 15;

  /// Rango admisible de días de sangrado (debe coincidir con el backend).
  static const int minSangrado = 1;
  static const int maxSangrado = 15;

  /// Días de sangrado registrados, o null si no hay dato utilizable.
  ///
  /// Ojo con el 0: un ciclo sin dato nunca debe pasar por registrado.
  static int? sangradoRegistrado(int? valor) {
    if (valor == null) return null;
    if (valor < minSangrado || valor > maxSangrado) return null;
    return valor;
  }

  /// Prepara los registros y calcula las medias UNA sola vez.
  ///
  /// El calendario pinta ~42 celdas por mes; recalcular el promedio en cada
  /// celda sería O(n²) sobre el histórico completo.
  static CycleStats buildStats(
    List<CycleLog>? cycleLogs, {
    int cycleLength = cicloEstandar,
    int periodLength = 5,
  }) {
    final logs = (cycleLogs ?? const <CycleLog>[])
        .where((l) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(l.fechaInicio))
        .toList()
      // De más reciente a más antiguo.
      ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));

    var avgCycleLength = cycleLength;
    var ciclosUsados = 0;

    if (logs.length >= 2) {
      // Ventana móvil: un ciclo anómalo de hace dos años no debe seguir
      // arrastrando la predicción de este mes.
      final pares = math.min(logs.length - 1, ventanaCiclos);
      var totalDays = 0;
      for (var i = 0; i < pares; i++) {
        final dias = AppDate.daysBetween(
          logs[i + 1].fechaInicio,
          logs[i].fechaInicio,
        );
        if (dias >= minCicloValido && dias <= maxCicloValido) {
          totalDays += dias;
          ciclosUsados++;
        }
      }
      if (ciclosUsados > 0) {
        var average = totalDays / ciclosUsados;
        // Con menos de 3 ciclos observados la muestra es pobre: se completa
        // con el estándar de 28 días para que la predicción no dé bandazos.
        if (ciclosUsados < 3) {
          average = (totalDays + (3 - ciclosUsados) * cicloEstandar) / 3;
        }
        avgCycleLength = average.round();
      }
    }

    // Días de sangrado promedio sobre la misma ventana de ciclos recientes.
    var avgPeriodLength = periodLength;
    var sangradosUsados = 0;
    var total = 0;
    for (final log in logs.take(ventanaCiclos + 1)) {
      final d = sangradoRegistrado(log.diasSangrado);
      if (d != null) {
        total += d;
        sangradosUsados++;
      }
    }
    if (sangradosUsados > 0) {
      avgPeriodLength = (total / sangradosUsados).round();
    }

    return CycleStats(
      logs: logs,
      avgCycleLength: math.max(avgCycleLength, cicloMinimo),
      ciclosUsados: ciclosUsados,
      avgPeriodLength: avgPeriodLength,
      sangradosUsados: sangradosUsados,
    );
  }

  /// Días de sangrado efectivos de un ciclo: el registrado, o el promedio.
  static int _sangradoDe(CycleLog? log, CycleStats stats) {
    return sangradoRegistrado(log?.diasSangrado) ?? stats.avgPeriodLength;
  }

  /// Datos del ciclo para [dateStr].
  ///
  /// Devuelve null si el día es anterior al primer registro o si cae más allá
  /// del horizonte de proyección: en ambos casos no hay nada honesto que decir.
  static CycleDetails? detailsFor(String dateStr, CycleStats stats) {
    final logs = stats.logs;
    if (logs.isEmpty) return null;

    // Registro vigente para la fecha consultada y el inmediatamente posterior.
    var currentIndex = -1;
    for (var i = 0; i < logs.length; i++) {
      if (logs[i].fechaInicio.compareTo(dateStr) <= 0) {
        currentIndex = i;
        break;
      }
    }
    if (currentIndex == -1) return null; // anterior al primer registro

    final currentLog = logs[currentIndex];
    final nextLog = currentIndex > 0 ? logs[currentIndex - 1] : null;

    final dayOfCycle = AppDate.daysBetween(currentLog.fechaInicio, dateStr) + 1;
    final hoy = AppDate.today();
    final logId = currentLog.fechaInicio == dateStr ? currentLog.id : null;

    final periodo = _sangradoDe(currentLog, stats);
    final periodoEstimado = sangradoRegistrado(currentLog.diasSangrado) == null;

    late CyclePhase phase;
    late int dayInCurrentCycle;
    late int cicloRef;
    late bool esCicloObservado;
    var diasRetraso = 0;
    var inicioEsperado = currentLog.fechaInicio;

    if (nextLog != null) {
      // --- Ciclo cerrado: la duración es un hecho, no una predicción ---
      esCicloObservado = true;
      cicloRef = math.max(
        AppDate.daysBetween(currentLog.fechaInicio, nextLog.fechaInicio),
        1,
      );
      dayInCurrentCycle = dayOfCycle;

      final periodoEfectivo = math.min(periodo, cicloRef);
      final ovulationDay = cicloRef - 14;

      if (dayInCurrentCycle <= periodoEfectivo) {
        phase = CyclePhase.period;
      } else if (dayInCurrentCycle == ovulationDay) {
        phase = CyclePhase.ovulation;
      } else if (dayInCurrentCycle >= ovulationDay - 5 &&
          dayInCurrentCycle <= ovulationDay + 1) {
        phase = CyclePhase.fertile;
      } else if (dayInCurrentCycle < ovulationDay - 5) {
        phase = CyclePhase.follicular;
      } else {
        phase = CyclePhase.luteal;
      }
    } else {
      // --- Último registro: ciclo en curso y proyecciones ---
      cicloRef = stats.avgCycleLength;
      // Ciclo 0 = el real en curso. 1 y 2 = proyecciones.
      final cicloIndex = ((dayOfCycle - 1) / cicloRef).floor();
      if (cicloIndex > maxCiclosProyectados) return null; // horizonte agotado

      esCicloObservado = cicloIndex == 0;
      dayInCurrentCycle = ((dayOfCycle - 1) % cicloRef) + 1;
      inicioEsperado = AppDate.addDays(
        currentLog.fechaInicio,
        cicloIndex * cicloRef,
      );

      final ovulationDay = cicloRef - 14;

      // En una proyección no hay ciclo registrado: se usa el sangrado promedio.
      final periodoAqui = cicloIndex == 0 ? periodo : stats.avgPeriodLength;

      if (dayInCurrentCycle <= periodoAqui) {
        if (cicloIndex == 0) {
          phase = CyclePhase.period;
        } else if (inicioEsperado.compareTo(hoy) <= 0) {
          // Se esperaba en una fecha que ya pasó y no se registró: eso es un
          // retraso, no una predicción.
          phase = CyclePhase.latePeriod;
          diasRetraso = AppDate.daysBetween(inicioEsperado, hoy);
        } else {
          phase = CyclePhase.predictedPeriod;
        }
      } else if (dayInCurrentCycle == ovulationDay) {
        phase = CyclePhase.ovulation;
      } else if (dayInCurrentCycle >= ovulationDay - 5 &&
          dayInCurrentCycle <= ovulationDay + 1) {
        phase = CyclePhase.fertile;
      } else if (dayInCurrentCycle < ovulationDay - 5) {
        phase = CyclePhase.follicular;
      } else {
        phase = CyclePhase.luteal;
      }
    }

    final ovulationDay = cicloRef - 14;
    final description = _describe(
      phase: phase,
      dayInCurrentCycle: dayInCurrentCycle,
      ovulationDay: ovulationDay,
      periodo: periodo,
      periodoEstimado: periodoEstimado,
      cicloRef: cicloRef,
      ciclosUsados: stats.ciclosUsados,
      inicioEsperado: inicioEsperado,
      diasRetraso: diasRetraso,
    );

    final nextPeriodIn = math.max(0, cicloRef - dayInCurrentCycle + 1);
    final progressPercent = math.min((dayInCurrentCycle / cicloRef) * 100, 100.0);
    final dateTitle = dateStr == hoy
        ? 'Hoy es el día $dayInCurrentCycle del ciclo'
        : 'El ${AppDate.medium(dateStr)} (día $dayInCurrentCycle del ciclo)';

    return CycleDetails(
      phase: phase,
      description: description,
      dayInCurrentCycle: dayInCurrentCycle,
      nextPeriodIn: nextPeriodIn,
      diasRetraso: diasRetraso,
      progressPercent: progressPercent,
      dateTitle: dateTitle,
      actualCycleLength: cicloRef,
      esCicloObservado: esCicloObservado,
      diasSangrado: periodo,
      sangradoEstimado: periodoEstimado,
      logId: logId,
    );
  }

  /// Resumen del histórico: duración de cada ciclo cerrado y estado del actual.
  static List<CycleHistoryEntry> history(List<CycleLog>? cycleLogs) {
    final logs = buildStats(cycleLogs).logs;
    return List.generate(logs.length, (i) {
      final log = logs[i];
      // logs va de reciente a antiguo, así que el "siguiente" ciclo es i-1.
      final posterior = i > 0 ? logs[i - 1] : null;
      final duracion = posterior == null
          ? null
          : AppDate.daysBetween(log.fechaInicio, posterior.fechaInicio);
      return CycleHistoryEntry(
        log: log,
        duracion: duracion,
        diasSangrado: sangradoRegistrado(log.diasSangrado),
        enCurso: i == 0,
        anomalo: duracion != null &&
            (duracion < minCicloValido || duracion > maxCicloValido),
      );
    });
  }

  // --- Consejos por fase (texto idéntico al de la versión web) ---

  static const List<String> _tipsMenstruation = [
    'Día 1: Tu cuerpo está trabajando intensamente hoy. Si experimentas cólicos, no te exijas al 100%. Date el permiso de ir a tu propio ritmo, tomar algo caliente y priorizar lo más urgente en tu día.',
    'Día 2: Es normal sentir un bajón de energía hoy. Trata de incluir en tus comidas hierro extra (como espinacas, lentejas o carne) para compensar la pérdida y evitar el cansancio extremo.',
    'Día 3: La pesadez suele empezar a disminuir. Hoy puede ser un buen momento para una caminata corta y respirar profundo. Tu intuición está muy conectada, escúchala.',
    'Día 4: Vas recuperando la energía poco a poco. Puedes retomar algunas tareas que habías pospuesto. Recuerda mantenerte muy bien hidratada.',
    'Día 5: Tu mente comienza a sentirse más despejada y ligera. Si haces ejercicio, puedes subir levemente la intensidad. ¡Celebra este nuevo aire!',
    'Día 6+: Tu periodo está terminando o ha terminado. Empiezas a sentirte lista para la acción. Aprovecha para organizar tus metas para las próximas semanas.',
  ];

  static const List<String> _tipsFollicular = [
    'A medida que sube tu estrógeno, notarás un impulso en tu estado de ánimo. Hoy es un día ideal para planificar proyectos nuevos y ser creativa.',
    'Te sientes más resiliente y social. Si tienes una reunión importante, una presentación o quieres salir, tu carisma natural jugará a tu favor.',
    'Estás en una fase de alta productividad. Aprovecha tu concentración para sacar adelante tareas complejas o aprender algo nuevo.',
    'Tu piel luce mejor y tienes más resistencia física. Es un gran día para entrenamientos de fuerza o actividades que te reten un poco más.',
  ];

  static const List<String> _tipsFertile = [
    'Inicia tu ventana fértil. Tu libido puede empezar a subir naturalmente y tus sentidos se agudizan. Disfruta de esta conexión con tu cuerpo.',
    'Estás brillando. Biológicamente tu cuerpo te prepara para la ovulación, dándote un magnetismo especial. Si no deseas embarazo, maximiza tus precauciones.',
    'Tienes gran fluidez verbal y facilidad para conectar con otras personas. Hoy eres un imán natural, excelente para el trabajo en equipo o ventas.',
    'Tu nivel de energía está cerca del máximo. Físicamente te sientes fuerte, por lo que puedes disfrutar de actividades intensas o aventureras.',
    'Pico estrogénico a la vista. Confía en tu intuición y agilidad mental hoy; tu cerebro está trabajando a toda velocidad.',
    'Estás a un paso de la ovulación. Es normal notar mayor flujo cervical. Te sientes plena, segura y capaz de cualquier cosa.',
  ];

  static const String _tipOvulation =
      '¡Día de ovulación! Estás en la cima de tu ciclo. Tu confianza, energía vital y sociabilidad están al máximo. Aprovecha para brillar en cualquier ámbito, pero cuídate si tu objetivo no es concebir.';

  static const List<String> _tipsLuteal = [
    'La ovulación ha pasado y empiezas una transición. Es momento de enfocar tu energía hacia adentro. Ideal para trabajos detallados y de escritorio.',
    'Tu metabolismo está ligeramente acelerado, pero también pueden surgir antojos. Mantén snacks saludables a la mano, como nueces o fruta oscura.',
    'Si empiezas a sentir que tu paciencia disminuye, recuerda que es normal por el aumento de progesterona. Respira y no te tomes todo personal.',
    'Es un buen momento para ordenar tu espacio, organizar tu casa o tu oficina. El cuerpo busca el "nido" y el orden te dará paz mental.',
    'Si notas tensión emocional o sensibilidad (SPM), reduce la cafeína y la sal. Un baño caliente y un libro pueden ser tu mejor medicina hoy.',
  ];

  /// Índice cíclico seguro, equivalente al `pick` de la versión web.
  static String _pick(List<String> arr, int index) {
    if (arr.isEmpty) return '';
    final i = ((index % arr.length) + arr.length) % arr.length;
    return arr[i];
  }

  static String _describe({
    required CyclePhase phase,
    required int dayInCurrentCycle,
    required int ovulationDay,
    required int periodo,
    required bool periodoEstimado,
    required int cicloRef,
    required int ciclosUsados,
    required String inicioEsperado,
    required int diasRetraso,
  }) {
    switch (phase) {
      case CyclePhase.period:
        var text = _tipsMenstruation[
            math.min(dayInCurrentCycle - 1, _tipsMenstruation.length - 1)];
        if (periodoEstimado) {
          text +=
              ' (Duración estimada en $periodo días: edita este ciclo para indicar cuántos días te duró realmente.)';
        }
        return text;

      case CyclePhase.predictedPeriod:
        final base = ciclosUsados > 0
            ? '$ciclosUsados ciclo(s) más recientes'
            : 'datos por defecto';
        return 'Estimación basada en tus $base ($cicloRef días). Es una predicción: al registrar tu próximo periodo el calendario se recalcula solo.';

      case CyclePhase.latePeriod:
        return 'Tu periodo se esperaba el ${AppDate.long(inicioEsperado)} y aún no lo has registrado ($diasRetraso día(s) de retraso). El estrés, los cambios de rutina o las alteraciones hormonales son causas comunes. Si ya empezó, regístralo para recalcular el ciclo.';

      case CyclePhase.ovulation:
        return _tipOvulation;

      case CyclePhase.fertile:
        return _pick(_tipsFertile, dayInCurrentCycle - (ovulationDay - 5));

      case CyclePhase.follicular:
        return _pick(_tipsFollicular, dayInCurrentCycle - periodo - 1);

      case CyclePhase.luteal:
        return _pick(_tipsLuteal, dayInCurrentCycle - ovulationDay - 1);
    }
  }
}
