import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../animations/entrance.dart';
import 'app_sheet.dart';

/// Una opción de un selector.
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.subtitle,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final String? subtitle;
}

/// Campo con aspecto de desplegable que abre un selector en un sheet.
class PickerField<T> extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchable = false,
    this.accent,
  });

  final String label;
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Añade un buscador; útil cuando hay más de una docena de opciones.
  final bool searchable;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final selected = options.firstWhere(
      (o) => o.value == value,
      orElse: () => options.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: colors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: colors.bgTertiary,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: () async {
              final picked = await showAppSheet<T>(
                context,
                builder: (context) => _OptionList<T>(
                  title: label,
                  options: options,
                  selected: value,
                  searchable: searchable,
                  accent: accent,
                ),
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  if (selected.icon != null) ...[
                    Icon(
                      selected.icon,
                      size: 20,
                      color: selected.color ?? colors.accent,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      selected.label,
                      style: text.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionList<T> extends StatefulWidget {
  const _OptionList({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
    this.accent,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T selected;
  final bool searchable;
  final Color? accent;

  @override
  State<_OptionList<T>> createState() => _OptionListState<T>();
}

class _OptionListState<T> extends State<_OptionList<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.accent ?? colors.accent;

    final filtered = _query.trim().isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.label.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return AppSheetScaffold(
      title: widget.title,
      accent: accent,
      maxHeightFactor: 0.75,
      child: Column(
        children: [
          if (widget.searchable) ...[
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                'No hay coincidencias',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (var i = 0; i < filtered.length; i++)
              FadeSlideIn(
                index: i,
                offset: 8,
                child: _OptionTile<T>(
                  option: filtered[i],
                  selected: filtered[i].value == widget.selected,
                  accent: accent,
                  onTap: () => Navigator.of(context).pop(filtered[i].value),
                ),
              ),
        ],
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final PickerOption<T> option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final color = option.color ?? accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.1) : colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: AnimatedContainer(
            duration: AppMotion.scale(context, AppMotion.quick),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: selected ? accent : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: text.bodyLarge),
                      if (option.subtitle != null)
                        Text(option.subtitle!, style: text.bodySmall),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 20, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de color en fila de círculos.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.colors,
    required this.selected,
    required this.onChanged,
    this.label = 'Color',
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: theme.textSecondary,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final color in colors)
              GestureDetector(
                onTap: () => onChanged(color),
                child: AnimatedContainer(
                  duration: AppMotion.scale(context, AppMotion.quick),
                  curve: AppMotion.overshoot,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.toARGB32() == selected.toARGB32()
                          ? Colors.white
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: color.toARGB32() == selected.toARGB32()
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: color.toARGB32() == selected.toARGB32()
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
