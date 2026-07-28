import '../../core/network/api_client.dart';

/// Ciclo menstrual, notas y hábitos.
class WellnessRepository {
  WellnessRepository(this._api);

  final ApiClient _api;

  // --- Ciclo ---

  Future<void> saveCycle({
    int? id,
    required String fechaInicio,
    String? observacion,
    int? diasSangrado,
  }) async {
    final body = {
      'fecha_inicio': fechaInicio,
      'observacion': observacion ?? '',
      // null = "sin registrar"; el backend lo distingue de 0.
      'dias_sangrado': diasSangrado,
    };
    if (id == null) {
      await _api.post('/api/cycles', body: body);
    } else {
      await _api.put('/api/cycles/$id', body: body);
    }
  }

  Future<void> deleteCycle(int id) => _api.delete('/api/cycles/$id');

  // --- Notas ---

  Future<void> createNote({
    required String fecha,
    required String contenido,
    String etiqueta = 'personal',
    String color = '#4FC3F7',
  }) async {
    await _api.post('/api/notes', body: {
      'fecha': fecha,
      'contenido': contenido,
      'etiqueta': etiqueta,
      'color': color,
    });
  }

  Future<void> updateNote({
    required int id,
    required String contenido,
    String etiqueta = 'personal',
    String color = '#4FC3F7',
  }) async {
    await _api.put('/api/notes/$id', body: {
      'contenido': contenido,
      'etiqueta': etiqueta,
      'color': color,
    });
  }

  Future<void> deleteNote(int id) => _api.delete('/api/notes/$id');

  // --- Hábitos ---

  Future<void> saveHabit({
    int? id,
    required String nombre,
    String icono = 'check_circle',
    String color = '#4CAF50',
    String frecuencia = 'diario',
    int metaDiaria = 1,
  }) async {
    final body = {
      'nombre': nombre,
      'icono': icono,
      'color': color,
      'frecuencia': frecuencia,
      'meta_diaria': metaDiaria,
      if (id != null) 'activo': true,
    };
    if (id == null) {
      await _api.post('/api/habits', body: body);
    } else {
      await _api.put('/api/habits/$id', body: body);
    }
  }

  Future<void> deleteHabit(int id) => _api.delete('/api/habits/$id');

  /// Marca o desmarca un hábito en una fecha. El endpoint hace UPSERT sobre
  /// (hábito, fecha), así que sirve para ambas direcciones.
  Future<void> logHabit({
    required int habitId,
    required String fecha,
    required bool completado,
    int cantidad = 1,
  }) async {
    await _api.post('/api/habits/log', body: {
      'habito_id': habitId,
      'fecha': fecha,
      'completado': completado,
      'cantidad': cantidad,
    });
  }
}
