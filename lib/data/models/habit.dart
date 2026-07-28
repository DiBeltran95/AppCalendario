import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/material_icon_map.dart';
import 'finance.dart' show parseHexColor;

/// Hábito recurrente (`habitos`).
class Habit {
  const Habit({
    required this.id,
    required this.nombre,
    this.icono = 'check_circle',
    this.color = '#4CAF50',
    this.frecuencia = 'diario',
    this.metaDiaria = 1,
    this.activo = true,
  });

  final int id;
  final String nombre;
  final String icono;
  final String color;
  final String frecuencia;
  final int metaDiaria;
  final bool activo;

  IconData get iconData => MaterialIconMap.resolve(icono);
  Color get accentColor => parseHexColor(color, fallback: const Color(0xFF4CAF50));

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: asInt(json['id']),
        nombre: asString(json['nombre'], fallback: 'Hábito'),
        icono: asString(json['icono'], fallback: 'check_circle'),
        color: asString(json['color'], fallback: '#4CAF50'),
        frecuencia: asString(json['frecuencia'], fallback: 'diario'),
        metaDiaria: asInt(json['meta_diaria'], fallback: 1),
        activo: asBool(json['activo'], fallback: true),
      );

  static const List<({String value, String label})> frequencies = [
    (value: 'diario', label: 'Diario'),
    (value: 'semanal', label: 'Semanal'),
    (value: 'mensual', label: 'Mensual'),
  ];

  static const List<Color> palette = [
    Color(0xFF4CAF50),
    Color(0xFF29B6F6),
    Color(0xFFFFCA28),
    Color(0xFFFF7043),
    Color(0xFFAB47BC),
    Color(0xFF26A69A),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
  ];
}

/// Marca de un hábito en un día concreto (`habitos_log`).
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitoId,
    required this.fecha,
    this.cantidad = 1,
    this.completado = true,
  });

  final int id;
  final int habitoId;
  final String fecha;
  final int cantidad;
  final bool completado;

  factory HabitLog.fromJson(Map<String, dynamic> json) => HabitLog(
        id: asInt(json['id']),
        habitoId: asInt(json['habito_id']),
        fecha: AppDate.normalize(json['fecha']),
        cantidad: asInt(json['cantidad'], fallback: 1),
        completado: asBool(json['completado'], fallback: true),
      );
}

/// Cálculo de rachas, portado desde `getHabitStreak` del Dashboard.
///
/// Cuenta días consecutivos hacia atrás desde hoy. Si hoy todavía no está
/// marcado no rompe la racha: se empieza a contar desde ayer, porque el día
/// aún no ha terminado.
int calculateStreak(int habitId, List<HabitLog> logs) {
  final done = logs
      .where((l) => l.habitoId == habitId && l.completado)
      .map((l) => l.fecha)
      .toSet();
  if (done.isEmpty) return 0;

  final today = AppDate.today();
  var cursor = today;

  if (!done.contains(today)) {
    cursor = AppDate.addDays(today, -1);
    if (!done.contains(cursor)) return 0;
  }

  var streak = 0;
  // Tope defensivo: dos años es más que suficiente y evita bucles largos.
  while (done.contains(cursor) && streak < 730) {
    streak++;
    cursor = AppDate.addDays(cursor, -1);
  }
  return streak;
}
