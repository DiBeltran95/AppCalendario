import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Caché *stale-while-revalidate*, igual que el `readCache`/`writeCache` del
/// Dashboard web: se pinta al instante lo último que se vio y en paralelo se
/// refresca contra el backend.
///
/// Es lo que hace que abrir la app se sienta instantáneo aunque la red esté
/// lenta.
class CacheStore {
  CacheStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'cache_';

  /// Más allá de esto, el dato se considera demasiado viejo para pintarlo.
  static const Duration maxAge = Duration(days: 7);

  String _key(String key) => '$_prefix$key';

  Map<String, dynamic>? readMap(String key) {
    final entry = _read(key);
    if (entry is Map) return Map<String, dynamic>.from(entry);
    return null;
  }

  List<Map<String, dynamic>>? readList(String key) {
    final entry = _read(key);
    if (entry is List) {
      return entry.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  dynamic _read(String key) {
    final raw = _prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = decoded['savedAt'];
      if (savedAt is int) {
        final age = DateTime.now().millisecondsSinceEpoch - savedAt;
        if (age > maxAge.inMilliseconds) {
          _prefs.remove(_key(key));
          return null;
        }
      }
      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? data) async {
    if (data == null) return;
    try {
      await _prefs.setString(
        _key(key),
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (_) {
      // Un fallo de caché nunca debe romper el flujo de datos.
    }
  }

  /// Borra todo lo cacheado; se usa al cerrar sesión y desde Ajustes.
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  // --- Claves usadas por la app ---

  static String bootstrap(int userId) => 'bootstrap_$userId';
  static String month(int userId, int year, int month) =>
      'month_${userId}_${year}_$month';
  static String holidays(int year) => 'holidays_CO_$year';
  static String importantDays(int year) => 'important_days_$year';

  // --- Banderas de UI que sobreviven al cierre de la app ---

  bool flag(String key) => _prefs.getBool(key) ?? false;
  Future<void> setFlag(String key, bool value) => _prefs.setBool(key, value);

  static String onboardingDismissed(int userId) => 'onboarding_fin_$userId';
  static String coachSeen(int userId, String coach) => 'coach_${coach}_$userId';
}
