import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import '../../app/theme/app_colors.dart';

/// Registro de inicio de periodo (`ciclos_menstruales`).
///
/// Cada registro marca el **día 1** de un ciclo.
class CycleLog {
  const CycleLog({
    required this.id,
    required this.fechaInicio,
    this.observacion,
    this.diasSangrado,
  });

  final int? id;

  /// `YYYY-MM-DD`.
  final String fechaInicio;

  final String? observacion;

  /// Días de sangrado de ESE ciclo. null = sin registrar.
  final int? diasSangrado;

  factory CycleLog.fromJson(Map<String, dynamic> json) => CycleLog(
        id: asIntOrNull(json['id']),
        fechaInicio: AppDate.normalize(json['fecha_inicio']),
        observacion: asStringOrNull(json['observacion']),
        diasSangrado: asIntOrNull(json['dias_sangrado']),
      );
}

/// Fase del ciclo. Los identificadores coinciden con los de la versión web para
/// que el comportamiento sea idéntico.
enum CyclePhase {
  period('period', 'Menstruación', 'Baja', AppColors.phaseLuteal),
  predictedPeriod('predicted-period', 'Periodo Previsto', 'Baja', AppColors.phaseLuteal),
  latePeriod('late-period', 'Periodo con Retraso', 'Baja', AppColors.phaseLate),
  ovulation('ovulation', 'Ovulación', 'Máxima', AppColors.phasePeriod),
  fertile('fertile', 'Ventana Fértil', 'Alta', Color(0xFFFF9800)),
  follicular('follicular', 'Fase Folicular', 'Media-Baja', AppColors.phaseFollicular),
  luteal('luteal', 'Fase Lútea', 'Baja', AppColors.phaseLuteal);

  const CyclePhase(this.key, this.label, this.fertilityChance, this.color);

  final String key;
  final String label;

  /// Probabilidad de embarazo asociada a la fase.
  final String fertilityChance;

  /// Color con el que se pinta la fase (mismo que el CSS original).
  final Color color;

  /// Color con el que se pinta la celda del calendario.
  Color get cellColor => switch (this) {
        CyclePhase.period => AppColors.phasePeriod,
        CyclePhase.predictedPeriod => AppColors.phasePeriod,
        CyclePhase.latePeriod => AppColors.phaseLate,
        CyclePhase.fertile => AppColors.phaseFertile,
        CyclePhase.ovulation => AppColors.phaseOvulation,
        CyclePhase.follicular => AppColors.phaseFollicular,
        CyclePhase.luteal => AppColors.phaseLuteal,
      };

  /// Emoji indicador en la celda; null si la fase no lleva marca.
  String? get badge => switch (this) {
        CyclePhase.period || CyclePhase.predictedPeriod => '🩸',
        CyclePhase.latePeriod => '⏳',
        CyclePhase.fertile => '🌸',
        CyclePhase.ovulation => '✨',
        _ => null,
      };
}

/// Estadísticas del histórico, calculadas una sola vez por render.
class CycleStats {
  const CycleStats({
    required this.logs,
    required this.avgCycleLength,
    required this.ciclosUsados,
    required this.avgPeriodLength,
    required this.sangradosUsados,
  });

  /// Registros normalizados y ordenados de **más reciente a más antiguo**.
  final List<CycleLog> logs;

  /// Duración estimada del ciclo a partir de la ventana móvil.
  final int avgCycleLength;

  /// Cuántos ciclos reales entraron en el promedio (0 = solo el estándar).
  final int ciclosUsados;

  /// Días de sangrado promedio, usado cuando un ciclo no lo registró.
  final int avgPeriodLength;

  /// Cuántos registros aportaron días de sangrado.
  final int sangradosUsados;

  bool get isEmpty => logs.isEmpty;
}

/// Datos del ciclo para un día concreto.
class CycleDetails {
  const CycleDetails({
    required this.phase,
    required this.description,
    required this.dayInCurrentCycle,
    required this.nextPeriodIn,
    required this.diasRetraso,
    required this.progressPercent,
    required this.dateTitle,
    required this.actualCycleLength,
    required this.esCicloObservado,
    required this.diasSangrado,
    required this.sangradoEstimado,
    this.logId,
  });

  final CyclePhase phase;
  final String description;
  final int dayInCurrentCycle;
  final int nextPeriodIn;

  /// Días de retraso respecto a la fecha esperada; 0 si no hay retraso.
  final int diasRetraso;

  final double progressPercent;
  final String dateTitle;
  final int actualCycleLength;

  /// true si la duración viene de un registro real; false si es estimación.
  final bool esCicloObservado;

  final int diasSangrado;

  /// true si esos días son el promedio y no un dato registrado.
  final bool sangradoEstimado;

  /// Id del registro cuando el día consultado es exactamente un día 1.
  final int? logId;
}

/// Resumen de un ciclo para el panel de historial.
class CycleHistoryEntry {
  const CycleHistoryEntry({
    required this.log,
    required this.duracion,
    required this.enCurso,
    required this.anomalo,
    required this.diasSangrado,
  });

  final CycleLog log;

  /// Días hasta el siguiente registro; null si es el ciclo en curso.
  final int? duracion;

  final bool enCurso;

  /// Fuera del rango 20-45 días: no entra en el promedio.
  final bool anomalo;

  final int? diasSangrado;

  String get fechaInicio => log.fechaInicio;
  String? get observacion => log.observacion;
}
