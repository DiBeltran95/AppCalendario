import 'package:dio/dio.dart';

/// Error de API ya traducido a algo que se le puede mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;

  /// Cuerpo de la respuesta, cuando el backend manda campos extra
  /// (por ejemplo `verification_required` en el login).
  final Map<String, dynamic>? data;

  /// La sesión ya no sirve: hay que sacar al usuario.
  bool get isUnauthorized => statusCode == 401;

  /// El backend respondió, pero rechazó la petición por permisos.
  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  /// No hubo respuesta: sin red, timeout o servidor caído.
  bool get isNetwork => statusCode == null;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      final response = error.response;

      if (response != null) {
        final data = response.data;
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        final message = map?['message']?.toString() ??
            map?['error']?.toString() ??
            _statusMessage(response.statusCode);
        return ApiException(
          message,
          statusCode: response.statusCode,
          data: map,
        );
      }

      return ApiException(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'El servidor tardó demasiado en responder. Revisa tu conexión.',
        DioExceptionType.connectionError =>
          'No pudimos conectar con el servidor. Revisa tu conexión a internet.',
        DioExceptionType.cancel => 'Petición cancelada.',
        _ => 'Ocurrió un error de conexión. Inténtalo de nuevo.',
      });
    }

    return ApiException('Ocurrió un error inesperado. Inténtalo de nuevo.');
  }

  static String _statusMessage(int? code) => switch (code) {
        400 => 'Los datos enviados no son válidos.',
        401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
        403 => 'No tienes permiso para hacer esto.',
        404 => 'No encontramos lo que buscabas.',
        409 => 'Ese registro ya existe.',
        final c? when c >= 500 =>
          'El servidor tuvo un problema. Inténtalo en unos minutos.',
        _ => 'Ocurrió un error. Inténtalo de nuevo.',
      };

  @override
  String toString() => message;
}
