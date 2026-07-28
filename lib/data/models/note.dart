import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import 'finance.dart' show parseHexColor;

/// Nota rápida asociada a un día (`notas`).
class Note {
  const Note({
    required this.id,
    required this.fecha,
    required this.contenido,
    this.etiqueta = 'personal',
    this.color = '#4FC3F7',
  });

  final int id;
  final String fecha;
  final String contenido;
  final String etiqueta;
  final String color;

  Color get accentColor => parseHexColor(color, fallback: const Color(0xFF4FC3F7));

  /// Primera línea, para vistas compactas.
  String get preview {
    final line = contenido.trim().split('\n').first;
    return line.length > 80 ? '${line.substring(0, 80)}…' : line;
  }

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: asInt(json['id']),
        fecha: AppDate.normalize(json['fecha']),
        contenido: asString(json['contenido']),
        etiqueta: asString(json['etiqueta'], fallback: 'personal'),
        color: asString(json['color'], fallback: '#4FC3F7'),
      );

  /// Etiquetas disponibles, con su color sugerido.
  static const List<({String value, String label, Color color})> tags = [
    (value: 'personal', label: 'Personal', color: Color(0xFF4FC3F7)),
    (value: 'trabajo', label: 'Trabajo', color: Color(0xFFAB47BC)),
    (value: 'idea', label: 'Idea', color: Color(0xFFFFCA28)),
    (value: 'recordatorio', label: 'Recordatorio', color: Color(0xFFFF7043)),
    (value: 'salud', label: 'Salud', color: Color(0xFF26A69A)),
  ];

  static const List<Color> palette = [
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFCA28),
    Color(0xFFFF8A65),
    Color(0xFFF06292),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
    Color(0xFFA1887F),
  ];
}
