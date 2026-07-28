import 'package:intl/intl.dart';

/// Utilidades de fecha.
///
/// Toda la app maneja las fechas como `String` en formato `YYYY-MM-DD`, igual
/// que el backend (`dateStrings: ['DATE']`) y que el frontend web. Así se evita
/// por completo el desfase de día por zona horaria, que es el error clásico en
/// Colombia (UTC-5).
abstract final class AppDate {
  static const List<String> monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  static const List<String> monthShort = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// Iniciales de la semana empezando en domingo, como en el calendario web.
  static const List<String> weekdayInitials = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

  static const List<String> weekdayNames = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado',
  ];

  /// `YYYY-MM-DD` en hora local, sin pasar por UTC.
  static String toKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String today() => toKey(DateTime.now());

  /// Normaliza lo que devuelva la API a `YYYY-MM-DD`.
  ///
  /// Acepta `"2025-06-12"`, un ISO con hora, o null. Con ISO usa los
  /// componentes **locales**, no los UTC.
  static String normalize(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return toKey(value);

    final s = value.toString();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

    final parsed = DateTime.tryParse(s);
    if (parsed != null) return toKey(parsed.toLocal());

    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  /// `YYYY-MM-DD` a medianoche local.
  static DateTime parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? 1970,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  static DateTime? tryParse(String? key) {
    if (key == null || key.isEmpty) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(key)) return null;
    return parse(key.substring(0, 10));
  }

  /// Días completos entre dos claves (b - a).
  ///
  /// El cálculo se hace en UTC a propósito: restar dos `DateTime` locales puede
  /// dar 23 o 25 horas si de por medio hay un cambio de horario, y entonces
  /// `inDays` se queda corto por uno.
  static int daysBetween(String a, String b) {
    final da = parse(a);
    final db = parse(b);
    final ua = DateTime.utc(da.year, da.month, da.day);
    final ub = DateTime.utc(db.year, db.month, db.day);
    return ub.difference(ua).inDays;
  }

  static String addDays(String key, int days) {
    final d = parse(key);
    return toKey(DateTime(d.year, d.month, d.day + days));
  }

  /// Formato largo: «12 de junio de 2025».
  static String long(String key) {
    final d = tryParse(key);
    if (d == null) return key;
    return '${d.day} de ${monthNames[d.month - 1].toLowerCase()} de ${d.year}';
  }

  /// Formato medio: «12 Jun».
  static String medium(String key) {
    final d = tryParse(key);
    if (d == null) return key;
    return '${d.day} ${monthShort[d.month - 1]}';
  }

  /// «Lunes, 12 de junio».
  static String weekdayLong(String key) {
    final d = tryParse(key);
    if (d == null) return key;
    final wd = weekdayNames[d.weekday % 7];
    return '$wd, ${d.day} de ${monthNames[d.month - 1].toLowerCase()}';
  }

  /// Etiqueta relativa útil en cabeceras: «Hoy», «Ayer», «Mañana».
  static String? relativeLabel(String key) {
    final diff = daysBetween(today(), key);
    return switch (diff) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => null,
    };
  }

  /// `HH:MM` desde el `HH:MM:SS` que devuelve MySQL.
  static String? shortTime(String? time) {
    if (time == null || time.isEmpty) return null;
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  /// Días del mes (mes 1-12).
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Día de la semana del día 1 con domingo = 0, que es como se dibuja la grilla.
  static int firstWeekdayIndex(int year, int month) {
    return DateTime(year, month, 1).weekday % 7;
  }

  /// Nombre del mes con año: «Junio 2025».
  static String monthLabel(int year, int month) {
    return '${monthNames[month - 1]} $year';
  }
}

/// Formato de moneda colombiana, sin decimales, como en el frontend web.
abstract final class AppCurrency {
  static final NumberFormat _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static final NumberFormat _plain = NumberFormat.decimalPattern('es_CO');

  static String format(num value) => _cop.format(value);

  /// Con signo explícito, para movimientos.
  static String signed(num value, {required bool isIncome}) {
    return '${isIncome ? '+' : '-'}${format(value.abs())}';
  }

  /// Compacto para ejes de gráficas: 1.2M, 350K.
  static String compact(num value) {
    final a = value.abs();
    if (a >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  /// Solo separadores de miles, sin símbolo (para inputs).
  static String plain(num value) => _plain.format(value);

  /// Extrae el número de un texto con separadores.
  static double parseInput(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }
}
