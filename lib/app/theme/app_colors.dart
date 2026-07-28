import 'package:flutter/material.dart';

import 'app_module.dart';

/// Paleta completa de un módulo.
///
/// Va como [ThemeExtension] para que `AnimatedTheme` pueda interpolar entre dos
/// módulos: al pasar de Finanzas a Ciclo no hay corte, todos los colores viajan
/// de un valor al otro. Es la diferencia con la versión web, que intercambia una
/// clase CSS de golpe.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.deep,
    required this.deepLight,
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.bgHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.divider,
    required this.success,
  });

  /// Color de marca del módulo.
  final Color accent;
  final Color accentDark;
  final Color accentLight;

  /// Tono profundo de apoyo (el `--wa-teal` de la versión web).
  final Color deep;
  final Color deepLight;

  /// Fondo de la pantalla.
  final Color bgPrimary;

  /// Fondo de contenedores y header.
  final Color bgSecondary;

  /// Fondos elevados: inputs, sheets, tarjetas.
  final Color bgTertiary;

  /// Estado presionado / seleccionado.
  final Color bgHover;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color border;
  final Color divider;
  final Color success;

  // --- Semánticos, iguales en los cinco temas ---

  static const Color danger = Color(0xFFF44336);
  static const Color dangerDark = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);
  static const Color income = Color(0xFF34E47E);
  static const Color expense = Color(0xFFF44336);
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color sky = Color(0xFF4FC3F7);

  // --- Fases del ciclo (comparten valores con el CSS original) ---

  static const Color phasePeriod = Color(0xFFE91E63);
  static const Color phasePeriodDark = Color(0xFFC2185B);
  static const Color phaseLate = Color(0xFFFF5252);
  static const Color phaseFertile = Color(0xFFFF69B4);
  static const Color phaseOvulation = Color(0xFF9C27B0);
  static const Color phaseOvulationLight = Color(0xFFBA68C8);
  static const Color phaseFollicular = Color(0xFF29B6F6);
  static const Color phaseLuteal = Color(0xFF03A9F4);

  // ------------------------------------------------------------------
  // Paletas por módulo — portadas 1:1 desde assets/css/styles.css
  // ------------------------------------------------------------------

  /// Tema base: WhatsApp Dark.
  static const AppColors agenda = AppColors(
    accent: Color(0xFF25D366),
    accentDark: Color(0xFF1DA855),
    accentLight: Color(0xFF34E47E),
    deep: Color(0xFF075E54),
    deepLight: Color(0xFF128C7E),
    bgPrimary: Color(0xFF0B141A),
    bgSecondary: Color(0xFF1C2A33),
    bgTertiary: Color(0xFF202C33),
    bgHover: Color(0xFF2A3942),
    textPrimary: Color(0xFFE9EDEF),
    textSecondary: Color(0xFF8696A0),
    textTertiary: Color(0xFF667781),
    border: Color(0xFF2A3942),
    divider: Color(0xFF323739),
    success: Color(0xFF25D366),
  );

  /// Finanzas: verde esmeralda con acentos en oro.
  static const AppColors finance = AppColors(
    accent: Color(0xFFFFD700),
    accentDark: Color(0xFFB8860B),
    accentLight: Color(0xFFFFDF00),
    deep: Color(0xFF104F31),
    deepLight: Color(0xFF166E43),
    bgPrimary: Color(0xFF08160E),
    bgSecondary: Color(0xFF0F2A1C),
    bgTertiary: Color(0xFF19462F),
    bgHover: Color(0xFF225F3F),
    textPrimary: Color(0xFFE6F7ED),
    textSecondary: Color(0xFF90CBA6),
    textTertiary: Color(0xFFFFD700),
    border: Color(0xFF225F3F),
    divider: Color(0xFF2D7D54),
    success: Color(0xFF34E47E),
  );

  /// Salud femenina: rosa y violeta.
  static const AppColors cycle = AppColors(
    accent: Color(0xFFFF4081),
    accentDark: Color(0xFFC51162),
    accentLight: Color(0xFFFF79B0),
    deep: Color(0xFF880E4F),
    deepLight: Color(0xFFC2185B),
    bgPrimary: Color(0xFF1A0F14),
    bgSecondary: Color(0xFF2D1B24),
    bgTertiary: Color(0xFF3E2432),
    bgHover: Color(0xFF4E2F40),
    textPrimary: Color(0xFFFCE4EC),
    textSecondary: Color(0xFFF48FB1),
    textTertiary: Color(0xFFF06292),
    border: Color(0xFF5C344A),
    divider: Color(0xFF6D3F58),
    success: Color(0xFFFF4081),
  );

  /// Notas: azul.
  static const AppColors notes = AppColors(
    accent: Color(0xFF4FC3F7),
    accentDark: Color(0xFF0288D1),
    accentLight: Color(0xFF81D4FA),
    deep: Color(0xFF0D47A1),
    deepLight: Color(0xFF1565C0),
    bgPrimary: Color(0xFF0A0F1D),
    bgSecondary: Color(0xFF121A30),
    bgTertiary: Color(0xFF1B2644),
    bgHover: Color(0xFF24335A),
    textPrimary: Color(0xFFE3F2FD),
    textSecondary: Color(0xFF90CAF9),
    textTertiary: Color(0xFF4FC3F7),
    border: Color(0xFF24335A),
    divider: Color(0xFF2C3E6B),
    success: Color(0xFF4FC3F7),
  );

  /// Hábitos: verde natural.
  static const AppColors habits = AppColors(
    accent: Color(0xFF4CAF50),
    accentDark: Color(0xFF388E3C),
    accentLight: Color(0xFF81C784),
    deep: Color(0xFF1B5E20),
    deepLight: Color(0xFF2E7D32),
    bgPrimary: Color(0xFF081209),
    bgSecondary: Color(0xFF102512),
    bgTertiary: Color(0xFF193B1D),
    bgHover: Color(0xFF225128),
    textPrimary: Color(0xFFE8F5E9),
    textSecondary: Color(0xFFA5D6A7),
    textTertiary: Color(0xFF4CAF50),
    border: Color(0xFF225128),
    divider: Color(0xFF2E6F37),
    success: Color(0xFF4CAF50),
  );

  static AppColors of(AppModule module) => switch (module) {
        AppModule.agenda => agenda,
        AppModule.finance => finance,
        AppModule.cycle => cycle,
        AppModule.notes => notes,
        AppModule.habits => habits,
      };

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentDark,
    Color? accentLight,
    Color? deep,
    Color? deepLight,
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgTertiary,
    Color? bgHover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? divider,
    Color? success,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      accentLight: accentLight ?? this.accentLight,
      deep: deep ?? this.deep,
      deepLight: deepLight ?? this.deepLight,
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgTertiary: bgTertiary ?? this.bgTertiary,
      bgHover: bgHover ?? this.bgHover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
    );
  }

  /// Interpolación color a color: esto es lo que hace fluido el cambio de módulo.
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      deep: Color.lerp(deep, other.deep, t)!,
      deepLight: Color.lerp(deepLight, other.deepLight, t)!,
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      bgTertiary: Color.lerp(bgTertiary, other.bgTertiary, t)!,
      bgHover: Color.lerp(bgHover, other.bgHover, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Acceso corto a la paleta: `context.colors.accent`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
