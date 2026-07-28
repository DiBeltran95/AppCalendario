import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/cache_store.dart';
import '../../core/utils/json_utils.dart';
import '../models/dashboard_data.dart';
import '../models/event.dart';

/// Carga de datos del calendario en dos niveles, igual que la versión web:
/// un bootstrap global por sesión y un fetch por mes.
///
/// Ambos pasan por caché *stale-while-revalidate*: se devuelve al instante lo
/// último guardado y en paralelo se refresca contra el backend.
class CalendarRepository {
  CalendarRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheStore _cache;

  /// Cliente aparte para la API de festivos: es un tercero, no lleva JWT y
  /// nunca debe poder colgar la carga del calendario.
  final Dio _holidaysDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  // --- Bootstrap ---

  BootstrapData? cachedBootstrap(int userId) {
    final raw = _cache.readMap(CacheStore.bootstrap(userId));
    return raw == null ? null : BootstrapData.fromJson(raw);
  }

  Future<BootstrapData> fetchBootstrap(int userId) async {
    final raw = await _api.getMap('/api/dashboard/bootstrap');
    await _cache.write(CacheStore.bootstrap(userId), raw);
    return BootstrapData.fromJson(raw);
  }

  // --- Mes ---

  MonthData? cachedMonth(int userId, int year, int month) {
    final raw = _cache.readMap(CacheStore.month(userId, year, month));
    return raw == null ? null : MonthData.fromJson(raw);
  }

  /// [month] va de 1 a 12, como lo espera el backend.
  Future<MonthData> fetchMonth(int userId, int year, int month) async {
    final raw = await _api.getMap(
      '/api/dashboard/month',
      query: {'mes': month, 'anio': year},
    );
    await _cache.write(CacheStore.month(userId, year, month), raw);
    return MonthData.fromJson(raw);
  }

  // --- Festivos (API pública de terceros) ---

  List<Holiday> cachedHolidays(int year) {
    final raw = _cache.readList(CacheStore.holidays(year));
    return raw == null ? const [] : raw.map(Holiday.fromJson).toList();
  }

  /// Los festivos de un año no cambian, así que la caché es la fuente principal
  /// y la red solo sirve para rellenarla la primera vez.
  Future<List<Holiday>> fetchHolidays(int year) async {
    try {
      final response = await _holidaysDio.get<dynamic>(
        'https://date.nager.at/api/v3/PublicHolidays/$year/CO',
      );
      final list = asMapList(response.data).map(Holiday.fromJson).toList();
      if (list.isNotEmpty) {
        await _cache.write(
          CacheStore.holidays(year),
          list.map((h) => h.toJson()).toList(),
        );
      }
      return list;
    } catch (_) {
      // Si el tercero falla o tarda, seguimos con lo que haya en caché.
      return cachedHolidays(year);
    }
  }

  // --- Días importantes (backend propio) ---

  List<ImportantDay> cachedImportantDays(int year) {
    final raw = _cache.readList(CacheStore.importantDays(year));
    return raw == null ? const [] : raw.map(ImportantDay.fromJson).toList();
  }

  Future<List<ImportantDay>> fetchImportantDays(int year) async {
    try {
      final raw = await _api.getList('/api/important-days', query: {'year': year});
      final list = raw.map(ImportantDay.fromJson).toList();
      await _cache.write(
        CacheStore.importantDays(year),
        list.map((d) => d.toJson()).toList(),
      );
      return list;
    } catch (_) {
      return cachedImportantDays(year);
    }
  }

  void dispose() => _holidaysDio.close(force: true);
}
