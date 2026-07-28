import '../../core/network/api_client.dart';
import '../models/finance.dart';

/// Todo el módulo de finanzas: cuentas, movimientos, transferencias, planes,
/// verificaciones, metas, presupuestos y categorías.
class FinanceRepository {
  FinanceRepository(this._api);

  final ApiClient _api;

  // --- Cuentas ---

  Future<void> saveAccount({
    int? id,
    required String nombre,
    required AccountType tipo,
    required double saldo,
    double limite = 0,
    double interesTasa = 0,
    String? fechaInicio,
    int plazoDias = 0,
    int? diaCorte,
  }) async {
    final body = {
      'nombre': nombre,
      'tipo': tipo.value,
      'saldo': saldo,
      'limite': limite,
      'interes_tasa': interesTasa,
      'fecha_inicio': fechaInicio,
      'plazo_dias': plazoDias,
      'dia_corte': diaCorte,
    };
    if (id == null) {
      await _api.post('/api/finanzas/cuentas', body: body);
    } else {
      await _api.put('/api/finanzas/cuentas/$id', body: body);
    }
  }

  Future<void> deleteAccount(int id) =>
      _api.delete('/api/finanzas/cuentas/$id');

  // --- Movimientos ---

  Future<void> saveTransaction({
    int? id,
    required String tipo,
    required double monto,
    required String descripcion,
    required String fecha,
    int? cuentaId,
    String categoria = 'otros',
    int cuotas = 1,
  }) async {
    final body = {
      'cuenta_id': cuentaId,
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
      'fecha': fecha,
      'categoria': categoria,
      'cuotas': cuotas,
    };
    if (id == null) {
      await _api.post('/api/finanzas/transacciones', body: body);
    } else {
      await _api.put('/api/finanzas/transacciones/$id', body: body);
    }
  }

  Future<void> deleteTransaction(int id) =>
      _api.delete('/api/finanzas/transacciones/$id');

  // --- Transferencias ---

  Future<void> createTransfer({
    required int cuentaOrigenId,
    required int cuentaDestinoId,
    required double monto,
    required String fecha,
    String descripcion = '',
  }) async {
    await _api.post('/api/finanzas/transferencias', body: {
      'cuenta_origen_id': cuentaOrigenId,
      'cuenta_destino_id': cuentaDestinoId,
      'monto': monto,
      'descripcion': descripcion,
      'fecha': fecha,
    });
  }

  Future<void> deleteTransfer(int id) =>
      _api.delete('/api/finanzas/transferencias/$id');

  // --- Ingresos planificados ---

  Future<void> createPlannedIncome({
    required String descripcion,
    required double monto,
    required String frecuencia,
    required String fechaInicio,
    int? cuentaId,
  }) async {
    await _api.post('/api/finanzas/ingresos-planificados', body: {
      'cuenta_id': cuentaId,
      'descripcion': descripcion,
      'monto': monto,
      'frecuencia': frecuencia,
      'fecha_inicio': fechaInicio,
    });
  }

  Future<void> deletePlannedIncome(int id) =>
      _api.delete('/api/finanzas/ingresos-planificados/$id');

  /// Confirma que un ingreso planificado llegó de verdad, con su fecha y monto
  /// reales. El backend crea de paso el movimiento correspondiente.
  Future<void> verifyPlannedIncome({
    required int planId,
    required String fechaEsperada,
    required String fechaReal,
    required double montoReal,
    int? cuentaId,
  }) async {
    await _api.post('/api/finanzas/ingresos-planificados/verificar', body: {
      'ingreso_planificado_id': planId,
      'fecha_esperada': fechaEsperada,
      'fecha_real': fechaReal,
      'monto_real': montoReal,
      'cuenta_id': cuentaId,
    });
  }

  Future<void> undoVerification(int verificationId) =>
      _api.delete('/api/finanzas/verificaciones/$verificationId');

  // --- Metas ---

  Future<void> saveGoal({
    int? id,
    required String nombre,
    String? descripcion,
    required double montoObjetivo,
    required double montoActual,
    String? fechaObjetivo,
    String icono = 'savings',
    String color = '#34E47E',
    bool completada = false,
  }) async {
    final body = {
      'nombre': nombre,
      'descripcion': descripcion,
      'monto_objetivo': montoObjetivo,
      'monto_actual': montoActual,
      'fecha_objetivo': (fechaObjetivo?.isEmpty ?? true) ? null : fechaObjetivo,
      'icono': icono,
      'color': color,
      if (id != null) 'completada': completada,
    };
    if (id == null) {
      await _api.post('/api/finanzas/metas', body: body);
    } else {
      await _api.put('/api/finanzas/metas/$id', body: body);
    }
  }

  Future<void> deleteGoal(int id) => _api.delete('/api/finanzas/metas/$id');

  // --- Presupuestos ---

  Future<void> saveBudget({
    required String categoria,
    required double montoLimite,
    required int mes,
    required int anio,
  }) async {
    // El endpoint hace UPSERT sobre (user, categoría, mes, año).
    await _api.post('/api/finanzas/presupuestos', body: {
      'categoria': categoria,
      'monto_limite': montoLimite,
      'mes': mes,
      'anio': anio,
    });
  }

  Future<void> deleteBudget(int id) =>
      _api.delete('/api/finanzas/presupuestos/$id');

  // --- Categorías ---

  Future<List<FinanceCategory>> fetchCategories() async {
    final raw = await _api.getList('/api/finanzas/categorias');
    return raw.map(FinanceCategory.fromJson).toList();
  }

  Future<void> createCategory({
    required String label,
    String icono = 'sell',
  }) async {
    await _api.post('/api/finanzas/categorias', body: {
      'label': label,
      'icono': icono,
    });
  }

  Future<void> deleteCategory(int id) =>
      _api.delete('/api/finanzas/categorias/$id');

  // --- Analíticas (carga perezosa, solo la pestaña de gráficos) ---

  Future<List<FinanceTransaction>> fetchAnalytics(int dias) async {
    final raw = await _api.getMap('/api/finanzas/analytics', query: {'dias': dias});
    final list = raw['transacciones'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => FinanceTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
