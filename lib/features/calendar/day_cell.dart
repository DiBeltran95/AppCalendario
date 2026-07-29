import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../data/models/cycle.dart';
import 'calendar_day.dart';
import 'day_content.dart';

/// Una celda del calendario.
///
/// A diferencia de la versión web —que solo pintaba puntos— cada celda muestra
/// **contenido real**: el nombre del cumpleañero, el título del evento, el
/// importe del día. El número del día va arriba a la izquierda para dejar el
/// resto del alto a la información, como en el mes de Google Calendar.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.data,
    required this.module,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final CalendarDay data;
  final AppModule module;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Etiquetas visibles antes del contador "+N".
  static const int _maxVisibleChips = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chips = DayContent.chipsFor(data, module, colors.accent);
    final surface = _surface(context);

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel(),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        // El doble toque se mantiene como alias del pulsado largo: quien viene
        // de la web ya lo tiene aprendido.
        onDoubleTap: onLongPress,
        child: AnimatedContainer(
          duration: AppMotion.scale(context, AppMotion.quick),
          curve: AppMotion.enter,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
          decoration: BoxDecoration(
            color: surface.background,
            gradient: surface.gradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colors.accent
                  : surface.borderColor ?? Colors.transparent,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DayNumber(
                day: data.day,
                isToday: data.isToday,
                color: surface.numberColor,
                accent: colors.accent,
                // Marca discreta cuando hay contenido que no cupo.
                extra: chips.length > _maxVisibleChips
                    ? chips.length - _maxVisibleChips
                    : 0,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final chip in chips.take(_maxVisibleChips))
                      _ChipBar(chip: chip),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Aspecto del fondo según módulo y estado del día ---

  _CellSurface _surface(BuildContext context) {
    final colors = context.colors;

    switch (module) {
      case AppModule.cycle:
        return switch (data.cycle?.phase) {
          CyclePhase.period => const _CellSurface(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.phasePeriodDark, AppColors.phasePeriod],
              ),
              numberColor: Colors.white,
            ),
          CyclePhase.ovulation => const _CellSurface(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.phaseOvulationLight,
                  AppColors.phaseOvulation,
                ],
              ),
              numberColor: Colors.white,
            ),
          CyclePhase.predictedPeriod => _CellSurface(
              background: AppColors.phasePeriod.withValues(alpha: 0.08),
              borderColor: AppColors.phasePeriod.withValues(alpha: 0.55),
              numberColor: AppColors.phasePeriod,
            ),
          CyclePhase.latePeriod => _CellSurface(
              background: AppColors.phaseLate.withValues(alpha: 0.12),
              borderColor: AppColors.phaseLate.withValues(alpha: 0.6),
              numberColor: AppColors.phaseLate,
            ),
          CyclePhase.fertile => _CellSurface(
              background: AppColors.phaseFertile.withValues(alpha: 0.16),
              borderColor: AppColors.phaseFertile.withValues(alpha: 0.45),
              numberColor: colors.textPrimary,
            ),
          _ => _CellSurface(
              background: colors.bgTertiary,
              numberColor: colors.textPrimary,
            ),
        };

      case AppModule.habits:
        final level = data.habitHeatLevel;
        if (level < 0) {
          return _CellSurface(
            background: colors.bgTertiary,
            numberColor: colors.textPrimary,
          );
        }
        // Mapa de calor: el acento gana peso conforme se cumplen hábitos.
        final intensity = [0.0, 0.05, 0.2, 0.38, 0.58, 0.8][level + 1];
        return _CellSurface(
          background: Color.lerp(colors.bgTertiary, colors.accent, intensity),
          numberColor: intensity > 0.5 ? Colors.white : colors.textPrimary,
        );

      case AppModule.finance:
        if (!data.hasFinance) {
          return _CellSurface(
            background: colors.bgTertiary,
            numberColor: colors.textPrimary,
          );
        }
        final tone = data.hasPendingFinance ? AppColors.warning : AppColors.income;
        return _CellSurface(
          background: tone.withValues(alpha: 0.09),
          borderColor: tone.withValues(alpha: 0.32),
          numberColor: colors.textPrimary,
        );

      case AppModule.notes:
        if (!data.hasNotes) {
          return _CellSurface(
            background: colors.bgTertiary,
            numberColor: colors.textPrimary,
          );
        }
        return _CellSurface(
          background: colors.accent.withValues(alpha: 0.1),
          borderColor: colors.accent.withValues(alpha: 0.3),
          numberColor: colors.textPrimary,
        );

      case AppModule.agenda:
        if (data.holiday != null) {
          return _CellSurface(
            background: AppColors.danger.withValues(alpha: 0.1),
            borderColor: AppColors.danger.withValues(alpha: 0.3),
            numberColor: AppColors.danger,
          );
        }
        if (data.importantDay != null) {
          return _CellSurface(
            background: AppColors.gold.withValues(alpha: 0.1),
            borderColor: AppColors.gold.withValues(alpha: 0.3),
            numberColor: AppColors.gold,
          );
        }
        return _CellSurface(
          background: colors.bgTertiary,
          numberColor: colors.textPrimary,
        );
    }
  }

  String _semanticLabel() {
    final parts = <String>['Día ${data.day}'];
    if (data.isToday) parts.add('hoy');
    if (selected) parts.add('seleccionado');

    switch (module) {
      case AppModule.agenda:
        if (data.holiday != null) {
          parts.add('festivo: ${data.holiday!.displayName}');
        }
        for (final birthday in data.birthdays) {
          parts.add('cumpleaños de ${birthday.nombre}');
        }
        for (final event in data.events) {
          parts.add(event.titulo);
        }
      case AppModule.finance:
        if (data.incomeTotal > 0) parts.add('ingresos registrados');
        if (data.expenseTotal > 0) parts.add('gastos registrados');
        if (data.hasPendingFinance) parts.add('con pendientes');
      case AppModule.cycle:
        if (data.cycle != null) parts.add(data.cycle!.phase.label);
      case AppModule.notes:
        if (data.hasNotes) parts.add('${data.notes.length} notas');
      case AppModule.habits:
        if (data.totalHabits > 0) {
          parts.add('${data.completedHabits} de ${data.totalHabits} hábitos');
        }
    }
    return parts.join(', ');
  }
}

/// Colores resueltos de una celda.
class _CellSurface {
  const _CellSurface({
    this.background,
    this.gradient,
    this.borderColor,
    required this.numberColor,
  });

  final Color? background;
  final Gradient? gradient;
  final Color? borderColor;
  final Color numberColor;
}

/// Número del día, arriba a la izquierda. Hoy lleva una pastilla de acento.
class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.day,
    required this.isToday,
    required this.color,
    required this.accent,
    required this.extra,
  });

  final int day;
  final bool isToday;
  final Color color;
  final Color accent;

  /// Cuántas etiquetas quedaron fuera.
  final int extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: AppMotion.scale(context, AppMotion.quick),
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: isToday ? accent : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 11.5,
              height: 1,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday
                  ? (accent.computeLuminance() > 0.45
                      ? const Color(0xFF0B141A)
                      : Colors.white)
                  : color,
            ),
          ),
        ),
        const Spacer(),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              '+$extra',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.65),
              ),
            ),
          ),
      ],
    );
  }
}

/// Barra de contenido: el nombre o título dentro de la celda.
class _ChipBar extends StatelessWidget {
  const _ChipBar({required this.chip});

  final DayChip chip;

  @override
  Widget build(BuildContext context) {
    final filled = chip.filled;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
      decoration: BoxDecoration(
        color: filled
            ? chip.color.withValues(alpha: 0.85)
            : chip.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip.emoji != null) ...[
            Text(chip.emoji!, style: const TextStyle(fontSize: 7.5, height: 1)),
            const SizedBox(width: 1.5),
          ],
          Flexible(
            child: Text(
              chip.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(
                fontSize: 8,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: filled
                    ? (chip.color.computeLuminance() > 0.6
                        ? const Color(0xFF0B141A)
                        : Colors.white)
                    : chip.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
