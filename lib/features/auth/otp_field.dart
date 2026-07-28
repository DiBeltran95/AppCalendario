import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';

/// Campo de código de verificación de 6 dígitos.
///
/// Cada caja hace *pop* al recibir su dígito y se ilumina; al completarse las
/// seis se envía solo. Pegar el código desde el portapapeles las rellena en
/// cascada. Un [errorTrigger] distinto sacude la fila entera.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.enabled = true,
    this.errorTrigger,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final bool enabled;

  /// Cambiar este valor dispara la animación de error.
  final Object? errorTrigger;

  @override
  State<OtpField> createState() => OtpFieldState();
}

class OtpFieldState extends State<OtpField> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode();

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final Animation<double> _shake = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

  String get value => _controller.text;

  /// Vacía el código; se llama tras un intento fallido.
  void clear() {
    _controller.clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  void didUpdateWidget(OtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorTrigger != oldWidget.errorTrigger &&
        widget.errorTrigger != null) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;

    if (trimmed != raw) {
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }

    setState(() {});
    HapticFeedback.selectionClick();

    if (trimmed.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = _controller.text.length;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shake.value, 0),
        child: child,
      ),
      child: Stack(
        children: [
          // El TextField real es invisible: solo sirve para captar el teclado
          // y el pegado. Lo que se ve son las seis cajas de abajo.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: widget.length,
                onChanged: _onChanged,
                showCursor: false,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.length; i++)
                  _OtpBox(
                    digit: i < filled ? _controller.text[i] : null,
                    active: i == filled && _focusNode.hasFocus,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDigit = digit != null;

    return AnimatedContainer(
      duration: AppMotion.scale(context, AppMotion.quick),
      curve: AppMotion.overshoot,
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: hasDigit
            ? colors.accent.withValues(alpha: 0.1)
            : colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: hasDigit || active ? colors.accent : colors.border,
          width: hasDigit || active ? 2 : 1,
        ),
        boxShadow: hasDigit || active
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: AppMotion.scale(context, AppMotion.instant),
          transitionBuilder: (child, animation) => ScaleTransition(
            // El dígito entra pasándose de tamaño y volviendo: el "pop".
            scale: Tween(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: AppMotion.overshoot),
            ),
            child: child,
          ),
          child: hasDigit
              ? Text(
                  digit!,
                  key: ValueKey(digit),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                )
              : _Caret(visible: active),
        ),
      ),
    );
  }
}

/// Cursor de la caja activa.
class _Caret extends StatefulWidget {
  const _Caret({required this.visible});

  final bool visible;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 24,
        color: context.colors.accent,
      ),
    );
  }
}
