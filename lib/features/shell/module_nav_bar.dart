import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/app_feedback.dart';

/// Barra inferior con indicador que se desliza entre destinos.
///
/// La píldora viaja de un icono a otro y **se estira mientras viaja** (más
/// ancha a mitad de camino que en reposo), lo que da la sensación de que tira
/// del destino en lugar de saltar. El icono activo además se eleva y toma el
/// color del módulo, que a esas alturas ya está tiñendo toda la pantalla.
class ModuleNavBar extends StatefulWidget {
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
  State<ModuleNavBar> createState() => _ModuleNavBarState();
}

class _ModuleNavBarState extends State<ModuleNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasized,
  );

  late double _from = _indexOf(widget.active).toDouble();
  late double _to = _from;

  int _indexOf(AppModule module) =>
      widget.modules.indexOf(module).clamp(0, widget.modules.length - 1);

  @override
  void didUpdateWidget(ModuleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _from = _to;
      _to = _indexOf(widget.active).toDouble();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / widget.modules.length;

              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = reduced
                          ? 1.0
                          : AppMotion.emphasizedCurve
                              .transform(_controller.value);
                      final position = _from + (_to - _from) * t;

                      // A mitad de camino la píldora se ensancha; en reposo
                      // vuelve a su tamaño. De ahí el efecto elástico.
                      final travel = (_to - _from).abs();
                      final stretch =
                          1 + (travel > 0 ? _bump(t) * 0.55 * travel.clamp(0, 2) : 0);
                      final width = slot * 0.66 * stretch;

                      return Positioned(
                        left: slot * position + (slot - width) / 2,
                        top: 8,
                        child: Container(
                          width: width,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: colors.accent.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      for (final module in widget.modules)
                        Expanded(
                          child: _NavItem(
                            module: module,
                            active: module == widget.active,
                            onTap: () {
                              if (module == widget.active) return;
                              AppFeedback.light();
                              widget.onSelect(module);
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

  /// Campana 0→1→0: vale 0 en los extremos y 1 en el centro del recorrido.
  double _bump(double t) => 1 - (2 * t - 1).abs();
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
            // El icono activo sube un par de píxeles: refuerza el destino sin
            // necesidad de más color.
            AnimatedSlide(
              offset: Offset(0, active ? -0.06 : 0),
              duration: AppMotion.scale(context, AppMotion.standard),
              curve: AppMotion.overshoot,
              child: AnimatedScale(
                scale: active ? 1.12 : 1,
                duration: AppMotion.scale(context, AppMotion.standard),
                curve: AppMotion.overshoot,
                child: Icon(module.icon, size: 21, color: color),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.scale(context, AppMotion.standard),
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: active ? 0.1 : 0,
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
