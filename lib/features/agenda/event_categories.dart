import 'package:flutter/material.dart';

/// Categorías de evento del calendario.
///
/// Los valores coinciden con los que ya hay guardados en `eventos.categoria`,
/// así que no se pueden renombrar sin migrar datos.
class EventCategory {
  const EventCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static const List<EventCategory> all = [
    EventCategory('reunion', 'Reunión', Icons.groups_rounded),
    EventCategory('cumpleanos', 'Cumpleaños', Icons.cake_rounded),
    EventCategory('moto', 'Moto', Icons.two_wheeler_rounded),
    EventCategory('carro', 'Carro', Icons.directions_car_rounded),
    EventCategory('casa', 'Casa', Icons.home_rounded),
    EventCategory('arriendo', 'Arriendo', Icons.real_estate_agent_rounded),
    EventCategory('aceite_moto', 'Aceite (Moto)', Icons.water_drop_rounded),
    EventCategory('mecanica', 'Mecánica', Icons.handyman_rounded),
    EventCategory('servicios', 'Servicios', Icons.receipt_long_rounded),
    EventCategory('doctor', 'Doctor', Icons.local_hospital_rounded),
    EventCategory('medicamentos', 'Medicamentos', Icons.medication_rounded),
    EventCategory('dentista', 'Dentista', Icons.health_and_safety_rounded),
    EventCategory('cita_amor', 'Cita amor', Icons.favorite_rounded),
    EventCategory('aniversario', 'Aniversario', Icons.celebration_rounded),
    EventCategory('matrimonio', 'Matrimonio', Icons.diversity_1_rounded),
    EventCategory('mesiversario', 'Mesiversario', Icons.favorite_border_rounded),
  ];

  /// Categoría especial: se guarda en la tabla `cumpleanos`, no en `eventos`.
  static const String birthdayValue = 'cumpleanos';

  static EventCategory resolve(String? value) {
    return all.firstWhere(
      (c) => c.value == value,
      orElse: () => all.first,
    );
  }

  static List<EventCategory> search(String query) {
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase().trim();
    return all.where((c) => c.label.toLowerCase().contains(q)).toList();
  }
}
