import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/app_feedback.dart';

/// Barra inferior con indicador que se desliza entre destinos.
///
/// La píldora viaja de un icono a otro y se estira mientras viaja (más ancha a
/// mitad de camino que en reposo), lo que da la sensación de que el indicador
/// "tira" del destino en lugar de saltar.
class ModuleNavBar extends StatelessWidget {
  const ModuleNavBar({
    super.key,
    required this.modules,
    required this.active,
    required this.onSelect,
  });

  final List<AppModule> modules;
  final AppModule active;
  final ValueChanged<AppModule> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final index = modules.indexOf(active).clamp(0, modules.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / modules.length;

              return Stack(
                children: [
                  // Píldora del indicador.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: index.toDouble(), end: index.toDouble()),
                    duration: AppMotion.scale(context, AppMotion.emphasized),
                    curve: AppMotion.emphasizedCurve,
                    builder: (context, value, _) {
                      // Cuanto más lejos del entero, más se estira: eso es el
                      // efecto "goo".
                      final stretch = 1 + (value - value.roundToDouble()).abs() * 1.4;
                      final width = slot * 0.62 * stretch;
                      return Positioned(
                        left: slot * value + (slot - width) / 2,
                        top: 8,
                        child: Container(
                          width: width,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      for (final module in modules)
                        Expanded(
                          child: _NavItem(
                            module: module,
                            active: module == active,
                            onTap: () {
                              if (module == active) return;
                              AppFeedback.light();
                              onSelect(module);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.module,
    required this.active,
    required this.onTap,
  });

  final AppModule module;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.accent : colors.textTertiary;

    return Semantics(
      selected: active,
      button: true,
      label: module.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1,
              duration: AppMotion.scale(context, AppMotion.standard),
              curve: AppMotion.overshoot,
              child: Icon(module.icon, size: 21, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.scale(context, AppMotion.standard),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(module.label),
            ),
          ],
        ),
      ),
    );
  }
}
