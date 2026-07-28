import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';

/// Campo de texto de la app.
///
/// La etiqueta va encima y **toma el color de acento al enfocar**, igual que el
/// `group-focus-within:text-green-400` de la versión web, pero animado.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.trailing,
    this.helperText,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final Widget? trailing;
  final String? helperText;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  bool _hidden = true;

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
    final obscured = widget.obscure && _hidden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: AppMotion.scale(context, AppMotion.quick),
          style: text.labelSmall!.copyWith(
            color: _focused ? colors.accent : colors.textSecondary,
            letterSpacing: 0.8,
          ),
          child: Text(widget.label.toUpperCase()),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: obscured,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          maxLines: obscured ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          style: text.bodyLarge,
          cursorColor: colors.accent,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            helperText: widget.helperText,
            helperStyle: text.bodySmall?.copyWith(color: colors.textTertiary),
            helperMaxLines: 3,
            prefixIcon: widget.icon == null
                ? null
                : AnimatedContainer(
                    duration: AppMotion.scale(context, AppMotion.quick),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: _focused ? colors.accent : colors.textTertiary,
                    ),
                  ),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    color: colors.textTertiary,
                  )
                : widget.trailing,
          ),
        ),
      ],
    );
  }
}
