import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_module.dart';
import 'app_spacing.dart';

/// Construye el [ThemeData] de cada módulo a partir de su [AppColors].
abstract final class AppTheme {
  static ThemeData forModule(AppModule module) => _build(AppColors.of(module));

  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme.dark(
      primary: c.accent,
      onPrimary: _onAccent(c.accent),
      primaryContainer: c.accentDark,
      secondary: c.accentLight,
      onSecondary: _onAccent(c.accentLight),
      surface: c.bgSecondary,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.bgTertiary,
      error: AppColors.danger,
      outline: c.border,
    );

    final text = _textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgPrimary,
      canvasColor: c.bgPrimary,
      dividerColor: c.divider,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text,
      fontFamily: 'Roboto',
      extensions: [c],

      appBarTheme: AppBarTheme(
        backgroundColor: c.bgSecondary,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: c.bgSecondary,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        color: c.bgTertiary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: c.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgTertiary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: c.textTertiary),
        labelStyle: text.labelLarge?.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.labelLarge?.copyWith(color: c.accent),
        border: _inputBorder(c.border),
        enabledBorder: _inputBorder(c.border),
        focusedBorder: _inputBorder(c.accent, width: 2),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 2),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: _onAccent(c.accent),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: c.accent.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),

      iconTheme: IconThemeData(color: c.textSecondary, size: 22),

      chipTheme: ChipThemeData(
        backgroundColor: c.bgTertiary,
        side: BorderSide(color: c.border),
        labelStyle: text.labelMedium!,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgSecondary,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: c.textTertiary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgTertiary,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.bgSecondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.bgHover,
        circularTrackColor: c.bgHover,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.accent.withValues(alpha: 0.3)
              : c.bgHover,
        ),
      ),

      dividerTheme: DividerThemeData(color: c.divider, space: 1, thickness: 1),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.bgHover,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        textStyle: text.bodySmall?.copyWith(color: c.textPrimary),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Negro sobre acentos claros (oro, verde lima), blanco sobre los oscuros.
  static Color _onAccent(Color accent) {
    return accent.computeLuminance() > 0.45 ? const Color(0xFF0B141A) : Colors.white;
  }

  static TextTheme _textTheme(AppColors c) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: c.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: c.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: c.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 15.5, height: 1.45, color: c.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: c.textSecondary),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.4, color: c.textSecondary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: c.textTertiary,
      ),
    );
  }
}
