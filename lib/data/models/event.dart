import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';

/// Tipo de movimiento asociado a un evento (`eventos.tipo_transaccion`).
enum TxKind {
  none('ninguno'),
  expense('gasto'),
  income('ingreso');

  const TxKind(this.value);
  final String value;

  static TxKind parse(dynamic v) {
    final s = asString(v, fallback: 'ninguno');
    return TxKind.values.firstWhere(
      (e) => e.value == s,
      orElse: () => TxKind.none,
    );
  }

  bool get isFinancial => this != TxKind.none;
}

/// Frecuencia de repetición (`eventos.frecuencia`).
///
/// El backend **materializa** las ocurrencias futuras en la tabla al crear el
/// evento, así que aquí solo se usa para el formulario y para mostrar la etiqueta.
enum EventFrequency {
  once('unica', 'Única'),
  daily('diaria', 'Diaria'),
  biweekly('quincenal', 'Quincenal'),
  monthly('mensual', 'Mensual'),
  quarterly('trimestral', 'Trimestral'),
  biannual('semestral', 'Semestral'),
  annual('anual', 'Anual');

  const EventFrequency(this.value, this.label);
  final String value;
  final String label;

  static EventFrequency parse(dynamic v) {
    final s = asString(v, fallback: 'unica');
    return EventFrequency.values.firstWhere(
      (e) => e.value == s,
      orElse: () => EventFrequency.once,
    );
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.hora,
    this.categoria = 'general',
    this.descripcion,
    this.ubicacion = '',
    this.frecuencia = EventFrequency.once,
    this.costo = 0,
    this.tipoTransaccion = TxKind.none,
    this.estadoPago = 'pendiente',
    this.uuidConfirmacion,
    this.parentId,
    this.tarjetaCreditoId,
    this.transaccionId,
  });

  final int id;
  final String titulo;

  /// `YYYY-MM-DD`.
  final String fecha;

  /// `HH:MM:SS`, o null si es un evento de todo el día.
  final String? hora;

  final String categoria;
  final String? descripcion;
  final String ubicacion;
  final EventFrequency frecuencia;
  final double costo;
  final TxKind tipoTransaccion;
  final String estadoPago;
  final String? uuidConfirmacion;
  final int? parentId;
  final int? tarjetaCreditoId;
  final int? transaccionId;

  bool get isPaid => estadoPago == 'pagado';
  bool get isPending => !isPaid;
  bool get isFinancial => tipoTransaccion.isFinancial;
  bool get isRecurring => frecuencia != EventFrequency.once;

  /// `HH:MM` o null.
  String? get shortTime => AppDate.shortTime(hora);

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: asInt(json['id']),
        titulo: asString(json['titulo'], fallback: 'Evento'),
        fecha: AppDate.normalize(json['fecha']),
        hora: asStringOrNull(json['hora']),
        categoria: asString(json['categoria'], fallback: 'general'),
        descripcion: asStringOrNull(json['descripcion']),
        ubicacion: asString(json['ubicacion']),
        frecuencia: EventFrequency.parse(json['frecuencia']),
        costo: asDouble(json['costo']),
        tipoTransaccion: TxKind.parse(json['tipo_transaccion']),
        estadoPago: asString(json['estado_pago'], fallback: 'pendiente'),
        uuidConfirmacion: asStringOrNull(json['uuid_confirmacion']),
        parentId: asIntOrNull(json['parent_id']),
        tarjetaCreditoId: asIntOrNull(json['tarjeta_credito_id']),
        transaccionId: asIntOrNull(json['transaccion_id']),
      );

  CalendarEvent copyWith({String? estadoPago}) => CalendarEvent(
        id: id,
        titulo: titulo,
        fecha: fecha,
        hora: hora,
        categoria: categoria,
        descripcion: descripcion,
        ubicacion: ubicacion,
        frecuencia: frecuencia,
        costo: costo,
        tipoTransaccion: tipoTransaccion,
        estadoPago: estadoPago ?? this.estadoPago,
        uuidConfirmacion: uuidConfirmacion,
        parentId: parentId,
        tarjetaCreditoId: tarjetaCreditoId,
        transaccionId: transaccionId,
      );
}

/// Cumpleaños (`cumpleanos`). Se guarda aparte de los eventos porque se repite
/// cada año comparando solo mes y día.
class Birthday {
  const Birthday({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.anioNacimiento,
    this.mensaje,
    this.telefono,
  });

  final int id;
  final String nombre;
  final String fecha;
  final int? anioNacimiento;
  final String? mensaje;
  final String? telefono;

  /// `MM-DD`, que es como se compara contra las celdas del calendario.
  String get monthDay => fecha.length >= 10 ? fecha.substring(5) : fecha;

  int? ageOn(int year) {
    if (anioNacimiento == null) return null;
    return year - anioNacimiento!;
  }

  factory Birthday.fromJson(Map<String, dynamic> json) => Birthday(
        id: asInt(json['id']),
        nombre: asString(json['nombre'], fallback: 'Sin nombre'),
        fecha: AppDate.normalize(json['fecha']),
        anioNacimiento: asIntOrNull(json['anio_nacimiento']),
        mensaje: asStringOrNull(json['mensaje']),
        telefono: asStringOrNull(json['telefono']),
      );
}

/// Festivo devuelto por la API pública `date.nager.at`.
class Holiday {
  const Holiday({required this.date, required this.name, this.localName, this.type});

  final String date;
  final String name;
  final String? localName;
  final String? type;

  String get displayName => localName?.isNotEmpty == true ? localName! : name;

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        date: AppDate.normalize(json['date']),
        name: asString(json['name']),
        localName: asStringOrNull(json['localName']),
        type: asStringOrNull(json['type']),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'name': name,
        'localName': localName,
        'type': type,
      };
}

/// Día importante que viene del backend (`/api/important-days`).
class ImportantDay {
  const ImportantDay({
    required this.date,
    required this.nombre,
    this.descripcion,
    this.categoria,
  });

  final String date;
  final String nombre;
  final String? descripcion;
  final String? categoria;

  factory ImportantDay.fromJson(Map<String, dynamic> json) => ImportantDay(
        date: AppDate.normalize(json['date'] ?? json['fecha']),
        nombre: asString(json['nombre']),
        descripcion: asStringOrNull(json['descripcion']),
        categoria: asStringOrNull(json['categoria']),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
      };
}
