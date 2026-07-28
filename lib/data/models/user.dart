import '../../core/utils/json_utils.dart';

/// Usuario de la sesión, tal como lo devuelve `/api/login`.
class AppUser {
  const AppUser({
    required this.id,
    required this.nombre,
    required this.email,
    this.whatsapp,
  });

  final int id;
  final String nombre;
  final String email;
  final String? whatsapp;

  /// Primer nombre, para los saludos.
  String get firstName {
    final parts = nombre.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Usuario' : parts.first;
  }

  String get initials {
    final parts = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.elementAt(1).substring(0, 1))
        .toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asInt(json['id']),
        nombre: asString(json['nombre'], fallback: 'Usuario'),
        email: asString(json['email']),
        whatsapp: asStringOrNull(json['whatsapp']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        if (whatsapp != null) 'whatsapp': whatsapp,
      };
}
