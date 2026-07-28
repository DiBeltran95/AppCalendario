import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Abre un bottom sheet con el estilo de la app.
///
/// Sustituye a los doce modales de la versión web: el sheet se puede arrastrar,
/// respeta el teclado y no tapa el campo activo.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: context.colors.bgSecondary,
    builder: (context) => Padding(
      // El teclado empuja el contenido en lugar de taparlo.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: builder(context),
    ),
  );
}

/// Contenido estándar de un sheet: cabecera con icono y título, cuerpo
/// desplazable y acciones fijas abajo.
class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.accent,
    this.actions,
    this.maxHeightFactor = 0.9,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? subtitle;
  final Color? accent;

  /// Botonera inferior; queda fija mientras el cuerpo hace scroll.
  final Widget? actions;

  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final accentColor = accent ?? colors.accent;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: child,
            ),
          ),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: actions!,
            )
          else
            const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Fila de botones Cancelar / Guardar para el pie de un sheet.
class SheetActions extends StatelessWidget {
  const SheetActions({
    super.key,
    required this.onConfirm,
    this.confirmLabel = 'Guardar',
    this.cancelLabel = 'Cancelar',
    this.loading = false,
    this.onDelete,
    this.accent,
  });

  final VoidCallback? onConfirm;
  final String confirmLabel;
  final String cancelLabel;
  final bool loading;

  /// Si se indica, aparece un botón de borrado a la izquierda.
  final VoidCallback? onDelete;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        if (onDelete != null) ...[
          IconButton(
            onPressed: loading ? null : onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.danger,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: AppColors.danger.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: loading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textSecondary,
              side: BorderSide(color: colors.border),
            ),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: loading ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: accent ?? colors.accent,
              minimumSize: const Size(0, 48),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
