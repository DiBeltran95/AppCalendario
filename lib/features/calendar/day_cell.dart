import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/models/cycle.dart';
import 'calendar_day.dart';

/// Una celda del calendario.
///
/// Cambia por completo de lenguaje visual según el módulo activo: los mismos
/// 30 días son puntos de evento, gotas de ciclo, importes o un mapa de calor.
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final decoration = _decorationFor(context);
    final numberColor = _numberColor(context);

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel(),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        // Se mantiene el doble toque como alias del pulsado largo: quien venía
        // de la web ya lo tiene aprendido.
        onDoubleTap: onLongPress,
        child: AnimatedContainer(
          duration: AppMotion.scale(context, AppMotion.quick),
          curve: AppMotion.enter,
          decoration: decoration,
          child: Stack(
            children: [
              // Anillo de "hoy", que respira.
              if (data.isToday) _TodayRing(color: colors.accent),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${data.day}',
                      style: text.labelLarge?.copyWith(
                        color: numberColor,
                        fontWeight: data.isToday || selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 14,
                      child: _Indicators(data: data, module: module),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Aspecto de la celda según el módulo ---

  BoxDecoration _decorationFor(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.chip);

    Color? background;
    Border? border;
    Gradient? gradient;

    switch (module) {
      case AppModule.cycle:
        final phase = data.cycle?.phase;
        switch (phase) {
          case CyclePhase.period:
            gradient = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.phasePeriodDark, AppColors.phasePeriod],
            );
          case CyclePhase.predictedPeriod:
            border = Border.all(color: AppColors.phasePeriod, width: 1.6);
          case CyclePhase.latePeriod:
            background = AppColors.phaseLate.withValues(alpha: 0.12);
            border = Border.all(color: AppColors.phaseLate, width: 1.6);
          case CyclePhase.fertile:
            background = AppColors.phaseFertile.withValues(alpha: 0.2);
            border = Border.all(
              color: AppColors.phaseFertile.withValues(alpha: 0.8),
              width: 1.6,
            );
          case CyclePhase.ovulation:
            gradient = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.phaseOvulationLight,
                AppColors.phaseOvulation,
              ],
            );
          case _:
            background = colors.bgTertiary;
        }

      case AppModule.finance:
        if (data.hasFinance) {
          background = (data.hasPendingFinance
                  ? AppColors.warning
                  : AppColors.income)
              .withValues(alpha: 0.14);
          border = Border.all(
            color: (data.hasPendingFinance
                    ? AppColors.warning
                    : AppColors.income)
                .withValues(alpha: 0.45),
          );
        } else {
          background = colors.bgTertiary;
        }

      case AppModule.notes:
        background = data.hasNotes
            ? colors.accent.withValues(alpha: 0.14)
            : colors.bgTertiary;
        if (data.hasNotes) {
          border = Border.all(color: colors.accent.withValues(alpha: 0.4));
        }

      case AppModule.habits:
        final level = data.habitHeatLevel;
        // Mapa de calor: la opacidad del acento crece con lo completado.
        background = level < 0
            ? colors.bgTertiary
            : Color.lerp(
                colors.bgTertiary,
                colors.accent,
                [0.0, 0.04, 0.18, 0.34, 0.55, 0.75][level + 1],
              );

      case AppModule.agenda:
        if (data.holiday != null) {
          background = AppColors.danger.withValues(alpha: 0.12);
          border = Border.all(color: AppColors.danger.withValues(alpha: 0.35));
        } else if (data.importantDay != null) {
          background = AppColors.gold.withValues(alpha: 0.12);
          border = Border.all(color: AppColors.gold.withValues(alpha: 0.35));
        } else {
          background = colors.bgTertiary;
        }
    }

    return BoxDecoration(
      color: gradient == null ? background : null,
      gradient: gradient,
      borderRadius: radius,
      border: selected
          ? Border.all(color: colors.accent, width: 2)
          : border ?? Border.all(color: Colors.transparent),
      boxShadow: selected
          ? [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ]
          : null,
    );
  }

  Color _numberColor(BuildContext context) {
    final colors = context.colors;

    if (module == AppModule.cycle) {
      return switch (data.cycle?.phase) {
        CyclePhase.period || CyclePhase.ovulation => Colors.white,
        CyclePhase.predictedPeriod => AppColors.phasePeriod,
        CyclePhase.latePeriod => AppColors.phaseLate,
        _ => colors.textPrimary,
      };
    }

    if (module == AppModule.agenda) {
      if (data.holiday != null) return AppColors.danger;
      if (data.importantDay != null) return AppColors.gold;
    }

    if (data.isToday) return colors.accent;
    return colors.textPrimary;
  }

  String _semanticLabel() {
    final parts = <String>['Día ${data.day}'];
    if (data.isToday) parts.add('hoy');
    if (selected) parts.add('seleccionado');

    switch (module) {
      case AppModule.agenda:
        if (data.holiday != null) parts.add('festivo: ${data.holiday!.displayName}');
        if (data.hasEvents) parts.add('${data.events.length} eventos');
        if (data.hasBirthdays) parts.add('${data.birthdays.length} cumpleaños');
      case AppModule.finance:
        if (data.hasFinance) {
          parts.add(data.hasPendingFinance
              ? 'movimientos pendientes'
              : 'movimientos registrados');
        }
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

/// Marcas bajo el número del día.
class _Indicators extends StatelessWidget {
  const _Indicators({required this.data, required this.module});

  final CalendarDay data;
  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    switch (module) {
      case AppModule.agenda:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (data.hasEvents)
              for (var i = 0; i < math.min(3, data.events.length); i++)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            if (data.hasBirthdays)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text('🎂', style: TextStyle(fontSize: 9)),
              ),
            if (data.holiday != null && !data.hasEvents && !data.hasBirthdays)
              const Text('🎉', style: TextStyle(fontSize: 9)),
          ],
        );

      case AppModule.cycle:
        final badge = data.cycle?.phase.badge;
        if (badge == null) return const SizedBox.shrink();
        return Opacity(
          opacity: data.cycle?.phase == CyclePhase.predictedPeriod ? 0.5 : 1,
          child: Text(badge, style: const TextStyle(fontSize: 9)),
        );

      case AppModule.finance:
        if (!data.hasFinance) return const SizedBox.shrink();
        return Icon(
          Icons.payments_rounded,
          size: 11,
          color: data.hasPendingFinance ? AppColors.warning : AppColors.income,
        );

      case AppModule.notes:
        if (!data.hasNotes) return const SizedBox.shrink();
        return Icon(Icons.edit_note_rounded, size: 13, color: colors.accent);

      case AppModule.habits:
        if (data.totalHabits == 0) return const SizedBox.shrink();
        return Text(
          '${data.completedHabits}/${data.totalHabits}',
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: data.habitCompletion >= 1
                ? Colors.white
                : colors.textSecondary,
          ),
        );
    }
  }
}

/// Anillo del día de hoy: late despacio para no competir con la selección.
class _TodayRing extends StatefulWidget {
  const _TodayRing({required this.color});

  final Color color;

  @override
  State<_TodayRing> createState() => _TodayRingState();
}

class _TodayRingState extends State<_TodayRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: widget.color.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.35 + t * 0.4),
                width: 1.4,
              ),
            ),
          );
        },
      ),
    );
  }
}
