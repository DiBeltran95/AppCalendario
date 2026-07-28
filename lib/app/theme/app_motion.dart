import 'package:flutter/material.dart';

/// Vocabulario de movimiento único de la app.
///
/// Regla: una sola animación protagonista por pantalla; el resto acompaña.
/// Todas las duraciones pasan por [scale], que las anula si el usuario pidió
/// reducir animaciones en los ajustes del sistema.
abstract final class AppMotion {
  /// Feedback táctil inmediato: ripples, cambios de estado de un botón.
  static const Duration instant = Duration(milliseconds: 100);

  /// Selección, checkboxes, hover.
  static const Duration quick = Duration(milliseconds: 200);

  /// Entradas de tarjeta, expansiones, la mayoría de transiciones.
  static const Duration standard = Duration(milliseconds: 300);

  /// Cambio de módulo (y por tanto de tema), transición entre páginas.
  static const Duration emphasized = Duration(milliseconds: 450);

  /// Reveals de pantalla completa y celebraciones.
  static const Duration dramatic = Duration(milliseconds: 700);

  /// Retardo entre elementos consecutivos de una lista.
  static const Duration stagger = Duration(milliseconds: 60);

  // --- Curvas ---

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
  static const Curve overshoot = Curves.easeOutBack;
  static const Curve reveal = Curves.easeOutQuint;

  /// Muelle suave para sheets y arrastres.
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 30,
  );

  /// Devuelve `Duration.zero` si el sistema pide animaciones reducidas.
  ///
  /// Se usa en cada widget animado en lugar de la constante directa, para que
  /// la app respete la preferencia de accesibilidad sin condicionales sueltos.
  static Duration scale(BuildContext context, Duration d) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
  }

  /// Retardo escalonado del elemento [index] de una lista, con tope para que
  /// las listas largas no acumulen segundos de espera.
  static Duration staggerFor(int index, {int max = 12}) {
    return stagger * (index > max ? max : index);
  }
}
