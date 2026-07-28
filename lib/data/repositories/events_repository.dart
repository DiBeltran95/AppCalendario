import '../../core/network/api_client.dart';
import '../models/event.dart';

/// Cómo aplicar un cambio sobre un evento que forma parte de una serie.
enum SeriesScope {
  /// Solo esta fecha.
  instance('instance'),

  /// Esta y todas las siguientes.
  future('future');

  const SeriesScope(this.value);
  final String value;
}

/// Eventos del calendario y cumpleaños.
class EventsRepository {
  EventsRepository(this._api);

  final ApiClient _api;

  // --- Eventos ---

  Future<void> create({
    required String titulo,
    required String fecha,
    String? hora,
    String categoria = 'general',
    String ubicacion = '',
    EventFrequency frecuencia = EventFrequency.once,
    double costo = 0,
    TxKind tipoTransaccion = TxKind.none,
    String estadoPago = 'pendiente',
  }) async {
    await _api.post('/api/events', body: {
      'titulo': titulo,
      'fecha': fecha,
      'hora': (hora == null || hora.isEmpty) ? null : hora,
      'categoria': categoria,
      'ubicacion': ubicacion,
      // El backend expande la serie a partir de `frecuencia` y deja
      // `repeticion` en 'unica' en cada ocurrencia generada.
      'repeticion': 'unica',
      'frecuencia': frecuencia.value,
      'costo': costo,
      'tipo_transaccion': tipoTransaccion.value,
      'estado_pago': estadoPago,
    });
  }

  Future<void> update({
    required int id,
    required String titulo,
    required String fecha,
    String? hora,
    String categoria = 'general',
    String ubicacion = '',
    EventFrequency frecuencia = EventFrequency.once,
    double costo = 0,
    TxKind tipoTransaccion = TxKind.none,
    String estadoPago = 'pendiente',
    SeriesScope scope = SeriesScope.instance,
  }) async {
    await _api.put(
      '/api/events/$id?editMode=${scope.value}',
      body: {
        'titulo': titulo,
        'fecha': fecha,
        'hora': (hora == null || hora.isEmpty) ? null : hora,
        'categoria': categoria,
        'ubicacion': ubicacion,
        'repeticion': 'unica',
        'frecuencia': frecuencia.value,
        'costo': costo,
        'tipo_transaccion': tipoTransaccion.value,
        'estado_pago': estadoPago,
      },
    );
  }

  Future<void> delete(int id, {SeriesScope scope = SeriesScope.instance}) async {
    await _api.delete('/api/events/$id?deleteMode=${scope.value}');
  }

  /// Alterna entre pendiente y pagado. El backend ajusta el saldo de la cuenta.
  Future<void> togglePayment(int id, {required bool markAsPaid}) async {
    await _api.put(
      '/api/events/$id/toggle-pago',
      body: {'estado_pago': markAsPaid ? 'pagado' : 'pendiente'},
    );
  }

  // --- Cumpleaños ---

  Future<void> createBirthday({
    required String nombre,
    required String fecha,
    int? anioNacimiento,
    String? mensaje,
    String? telefono,
  }) async {
    await _api.post('/api/cumpleanos', body: {
      'nombre': nombre,
      'fecha': fecha,
      'anio_nacimiento': anioNacimiento,
      'mensaje': mensaje,
      'telefono': telefono,
    });
  }

  Future<void> updateBirthday({
    required int id,
    required String nombre,
    required String fecha,
    int? anioNacimiento,
    String? mensaje,
    String? telefono,
  }) async {
    await _api.put('/api/cumpleanos/$id', body: {
      'nombre': nombre,
      'fecha': fecha,
      'anio_nacimiento': anioNacimiento,
      'mensaje': mensaje,
      'telefono': telefono,
    });
  }

  Future<void> deleteBirthday(int id) async {
    await _api.delete('/api/cumpleanos/$id');
  }
}
