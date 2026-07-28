/// Conversores tolerantes para las respuestas del backend.
///
/// El pool de MySQL devuelve `DECIMAL` como **string** (`"1500.00"`) y
/// `BOOLEAN` como `0`/`1`. El frontend web se salva porque `Number("1500.00")`
/// funciona; en Dart un cast directo revienta. Todo el parseo de la app pasa
/// por aquí.
library;

/// Número que puede llegar como int, double, string o null.
double asDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

int asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }
  return null;
}

/// MySQL manda 0/1; algunos drivers mandan true/false.
bool asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return fallback;
}

String asString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  return v.toString();
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Lista de mapas desde una respuesta que puede venir nula o mal tipada.
List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Aplica [parse] a cada elemento de una lista cruda del backend.
List<T> parseList<T>(dynamic v, T Function(Map<String, dynamic>) parse) {
  return asMapList(v).map(parse).toList();
}
