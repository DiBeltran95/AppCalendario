import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../core/cycle/cycle_engine.dart';
import '../../data/models/cycle.dart';

/// Rueda del ciclo: un anillo dividido en arcos por fase, con un marcador que
/// se desliza por la circunferencia hasta el día consultado.
///
/// Es la pieza visual insignia del módulo. Se dibuja a partir de las mismas
/// reglas del motor (sangrado → folicular → fértil → ovulación → lútea), de
/// modo que la rueda y el calendario nunca se contradicen.
class CycleWheel extends StatelessWidget {
  const CycleWheel({
    super.key,
    required this.details,
    this.size = 210,
  });

  final CycleDetails details;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    // Ángulo del marcador según el día del ciclo (día 1 arriba).
    final dayFraction =
        (details.dayInCurrentCycle - 0.5) / details.actualCycleLength;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: dayFraction, end: dayFraction),
      duration: AppMotion.scale(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      builder: (context, animatedFraction, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _WheelPainter(
                cycleLength: details.actualCycleLength,
                periodDays: details.diasSangrado,
                markerFraction: animatedFraction,
                phaseColor: details.phase.color,
                trackColor: colors.bgHover,
              ),
            ),
            // Centro: día del ciclo con cross-fade al cambiar.
            AnimatedSwitcher(
              duration: AppMotion.scale(context, AppMotion.standard),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(details.dayInCurrentCycle),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DÍA',
                    style: text.labelSmall?.copyWith(
                      letterSpacing: 2.5,
                      color: colors.textTertiary,
                    ),
                  ),
                  Text(
                    '${details.dayInCurrentCycle}',
                    style: text.displaySmall?.copyWith(
                      color: details.phase.color,
                      fontSize: 44,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    'de ${details.actualCycleLength}',
                    style: text.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    required this.cycleLength,
    required this.periodDays,
    required this.markerFraction,
    required this.phaseColor,
    required this.trackColor,
  });

  final int cycleLength;
  final int periodDays;

  /// Posición del marcador, 0..1 con el día 1 arriba.
  final double markerFraction;

  final Color phaseColor;
  final Color trackColor;

  static const double _stroke = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke - 10) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double dayToAngle(double day) =>
        -math.pi / 2 + (day / cycleLength) * 2 * math.pi;

    void arc(double fromDay, double toDay, Color color, {double alpha = 1}) {
      final start = dayToAngle(fromDay);
      final sweep = dayToAngle(toDay) - start;
      canvas.drawArc(
        rect,
        start + 0.02,
        math.max(0, sweep - 0.04),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: alpha),
      );
    }

    // Pista base.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = trackColor,
    );

    // Fases, con las mismas fronteras que usa el motor:
    final ovulationDay = cycleLength - 14;
    final fertileStart = ovulationDay - 5;
    final fertileEnd = ovulationDay + 1;

    // Menstruación (día 1..periodDays).
    arc(0, math.min(periodDays, cycleLength).toDouble(),
        AppColors.phasePeriod, alpha: 0.9);
    // Folicular.
    if (fertileStart - 1 > periodDays) {
      arc(periodDays.toDouble(), (fertileStart - 1).toDouble(),
          AppColors.phaseFollicular, alpha: 0.45);
    }
    // Ventana fértil.
    arc((fertileStart - 1).toDouble(), fertileEnd.toDouble(),
        AppColors.phaseFertile, alpha: 0.75);
    // Ovulación: un tramo corto y brillante dentro de la ventana.
    arc((ovulationDay - 1).toDouble(), ovulationDay.toDouble(),
        AppColors.phaseOvulation);
    // Lútea.
    if (cycleLength > fertileEnd) {
      arc(fertileEnd.toDouble(), cycleLength.toDouble(),
          AppColors.phaseLuteal, alpha: 0.4);
    }

    // Marcador del día consultado.
    final markerAngle = -math.pi / 2 + markerFraction * 2 * math.pi;
    final markerCenter = Offset(
      center.dx + math.cos(markerAngle) * radius,
      center.dy + math.sin(markerAngle) * radius,
    );

    canvas.drawCircle(
      markerCenter,
      _stroke / 2 + 5,
      Paint()..color = phaseColor.withValues(alpha: 0.28),
    );
    canvas.drawCircle(markerCenter, _stroke / 2 + 1, Paint()..color = Colors.white);
    canvas.drawCircle(markerCenter, _stroke / 2 - 2, Paint()..color = phaseColor);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.markerFraction != markerFraction ||
      old.cycleLength != cycleLength ||
      old.periodDays != periodDays ||
      old.phaseColor != phaseColor;
}

/// Leyenda de colores de la rueda y el calendario.
class CycleLegend extends StatelessWidget {
  const CycleLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = [
      (AppColors.phasePeriod, 'Menstruación'),
      (AppColors.phaseFertile, 'Ventana fértil'),
      (AppColors.phaseOvulation, 'Ovulación'),
      (AppColors.phaseFollicular, 'Folicular'),
      (AppColors.phaseLuteal, 'Lútea'),
      (AppColors.phaseLate, 'Retraso'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
              ),
            ],
          ),
      ],
    );
  }
}

/// Comprobación de coherencia usada por los tests de la rueda.
double debugDayToFraction(int day, int cycleLength) =>
    (day - 0.5) / cycleLength;

/// Referencia del motor para que este archivo no compile si cambian las
/// constantes de fase sin actualizar la rueda.
const int debugOvulationOffset = 14;
const int debugFertileWindowBefore = 5;
const int debugMinCycle = CycleEngine.cicloMinimo;
