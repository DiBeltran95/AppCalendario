import 'package:flutter/material.dart';

import '../../app/theme/app_motion.dart';
import '../../core/utils/date_utils.dart';

/// Número que cuenta desde su valor anterior hasta el nuevo.
///
/// Es el recurso que hace que un saldo se sienta "vivo" al entrar a la
/// pantalla, en lugar de aparecer de golpe.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.dramatic,
    this.formatter,
    this.textAlign,
  });

  final double value;
  final TextStyle? style;
  final Duration duration;

  /// Por defecto, moneda colombiana.
  final String Function(double)? formatter;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final format = formatter ?? AppCurrency.format;

    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(format(value), style: style, textAlign: textAlign);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.reveal,
      builder: (context, animated, _) => Text(
        format(animated),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// Entero que rueda hacia arriba o hacia abajo al cambiar, dígito completo.
/// Se usa para el año del calendario y para contadores pequeños.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    super.key,
    required this.value,
    this.style,
    this.forward = true,
  });

  final int value;
  final TextStyle? style;

  /// Dirección del rodillo: hacia arriba si avanza, hacia abajo si retrocede.
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.scale(context, AppMotion.standard),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final begin = Offset(0, forward ? 0.6 : -0.6);
        return ClipRect(
          child: SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Text('$value', key: ValueKey(value), style: style),
    );
  }
}
