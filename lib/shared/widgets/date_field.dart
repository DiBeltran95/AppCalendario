import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';

/// Campo de fecha reutilizable que abre el selector nativo.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;

  /// `YYYY-MM-DD`.
  final String value;

  final ValueChanged<String> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

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
              final picked = await showDatePicker(
                context: context,
                initialDate: AppDate.parse(value),
                firstDate: firstDate ?? DateTime(2000),
                lastDate: lastDate ?? DateTime(2100),
              );
              if (picked != null) onChanged(AppDate.toKey(picked));
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
                  Icon(Icons.calendar_today_rounded,
                      size: 18, color: colors.textTertiary),
                  const SizedBox(width: AppSpacing.md),
                  Text(AppDate.long(value), style: text.bodyLarge),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
