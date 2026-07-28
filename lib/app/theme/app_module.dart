import 'package:flutter/material.dart';

/// Los cinco módulos de la app. Cada uno tiene su propia paleta; cambiar de
/// módulo interpola el tema completo (ver [AppColors.lerp]).
enum AppModule {
  agenda,
  finance,
  cycle,
  notes,
  habits;

  String get label => switch (this) {
        AppModule.agenda => 'Agenda',
        AppModule.finance => 'Finanzas',
        AppModule.cycle => 'Ciclo',
        AppModule.notes => 'Notas',
        AppModule.habits => 'Hábitos',
      };

  /// Título largo que se muestra en el header.
  String get title => switch (this) {
        AppModule.agenda => 'Calendario de Eventos',
        AppModule.finance => 'Control Financiero',
        AppModule.cycle => 'Salud Femenina',
        AppModule.notes => 'Notas Rápidas',
        AppModule.habits => 'Hábitos y Rutinas',
      };

  IconData get icon => switch (this) {
        AppModule.agenda => Icons.event_rounded,
        AppModule.finance => Icons.payments_rounded,
        AppModule.cycle => Icons.female_rounded,
        AppModule.notes => Icons.edit_note_rounded,
        AppModule.habits => Icons.self_improvement_rounded,
      };

  /// Pista de interacción que aparece bajo el calendario.
  String get hint => switch (this) {
        AppModule.agenda =>
          'Toca un día para ver el detalle · Mantén pulsado para crear',
        AppModule.finance =>
          'Toca un día para filtrar · Mantén pulsado para registrar un movimiento',
        AppModule.cycle =>
          'Toca un día para ver tu ciclo · Mantén pulsado para registrar el periodo',
        AppModule.notes =>
          'Toca un día para ver sus notas · Mantén pulsado para crear una',
        AppModule.habits =>
          'Toca un día para marcar hábitos · Mantén pulsado para crear uno',
      };
}
