import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';

/// Formatea el importe con separadores de miles mientras se escribe.
///
/// Equivalente al componente `CurrencyInput.svelte`: el usuario teclea dígitos
/// y ve `1.250.000` en vivo, sin decimales (los pesos colombianos no los usan
/// en el día a día).
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Tope defensivo: 15 dígitos ya es más de lo que aguanta DECIMAL(12,2).
    final trimmed = digits.length > 12 ? digits.substring(0, 12) : digits;
    final formatted = AppCurrency.plain(int.parse(trimmed));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Campo de importe en pesos.
class CurrencyField extends StatefulWidget {
  const CurrencyField({
    super.key,
    required this.controller,
    this.label = 'Valor',
    this.accent,
    this.autofocus = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final Color? accent;
  final bool autofocus;
  final String? Function(String?)? validator;

  /// Lee el valor numérico del controlador.
  static double valueOf(TextEditingController controller) =>
      AppCurrency.parseInput(controller.text);

  /// Escribe un valor numérico en el controlador, ya formateado.
  static void setValue(TextEditingController controller, double value) {
    controller.text = value <= 0 ? '' : AppCurrency.plain(value.round());
  }

  @override
  State<CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<CurrencyField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final accent = widget.accent ?? colors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: AppMotion.scale(context, AppMotion.quick),
          style: text.labelSmall!.copyWith(
            color: _focused ? accent : colors.textSecondary,
            letterSpacing: 0.8,
          ),
          child: Text(widget.label.toUpperCase()),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          inputFormatters: [_ThousandsFormatter()],
          validator: widget.validator,
          cursorColor: accent,
          style: text.headlineSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: text.headlineSmall?.copyWith(color: colors.textTertiary),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.sm,
              ),
              child: Text(
                r'$',
                style: text.headlineSmall?.copyWith(
                  color: _focused ? accent : colors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
