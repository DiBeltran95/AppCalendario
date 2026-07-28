import 'package:flutter/material.dart';

import '../../app/theme/app_motion.dart';

/// Entrada estándar: aparece deslizándose desde abajo.
///
/// Con [index] la entrada se escalona, que es lo que convierte el "pop" de
/// datos que llegan del backend en algo intencional.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 16,
    this.duration = AppMotion.standard,
    this.delay = Duration.zero,
    this.horizontal = false,
  });

  final Widget child;

  /// Posición en la lista; define el retardo escalonado.
  final int index;

  /// Distancia del desplazamiento inicial, en píxeles lógicos.
  final double offset;

  final Duration duration;

  /// Retardo adicional, encima del escalonado.
  final Duration delay;

  /// Desliza desde la derecha en vez de desde abajo.
  final bool horizontal;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final wait = widget.delay + AppMotion.staggerFor(widget.index);
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.enter);

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final travel = widget.offset * (1 - curved.value);
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: widget.horizontal ? Offset(travel, 0) : Offset(0, travel),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Aplica [FadeSlideIn] a cada hijo, escalonando la entrada.
List<Widget> staggered(List<Widget> children, {int startIndex = 0}) {
  return [
    for (var i = 0; i < children.length; i++)
      FadeSlideIn(index: startIndex + i, child: children[i]),
  ];
}

/// Sacude horizontalmente al cambiar [trigger]. Se usa para señalar errores
/// sin escribir un mensaje: el gesto se entiende antes que el texto.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.child, required this.trigger});

  final Widget child;

  /// Cada vez que este valor cambia, la sacudida se dispara.
  final Object? trigger;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final Animation<double> _offset = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -8, end: 5), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger != null) {
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
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offset.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Escala el hijo mientras se mantiene pulsado. Da sensación física a
/// cualquier cosa tocable sin tener que rehacer el botón.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.scale(context, AppMotion.instant),
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}
