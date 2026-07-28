import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Feedback al usuario: mensajes y vibración, siempre con el mismo criterio.
abstract final class AppFeedback {
  // --- Háptica ---

  /// Al elegir algo: día del calendario, pestaña, opción.
  static void select() => HapticFeedback.selectionClick();

  /// Al navegar o abrir algo.
  static void light() => HapticFeedback.lightImpact();

  /// Al completar una acción: guardar, marcar un hábito.
  static void success() => HapticFeedback.mediumImpact();

  /// Al fallar algo.
  static void error() => HapticFeedback.heavyImpact();

  // --- Mensajes ---

  static void showSuccess(BuildContext context, String message) {
    success();
    _show(context, message, Icons.check_circle_rounded, context.colors.success);
  }

  static void showError(BuildContext context, String message) {
    error();
    _show(context, message, Icons.error_rounded, AppColors.danger);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Icons.info_rounded, AppColors.info);
  }

  /// Mensaje con acción de deshacer.
  static void showUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
  }) {
    _show(
      context,
      message,
      Icons.delete_rounded,
      AppColors.warning,
      action: SnackBarAction(
        label: 'Deshacer',
        textColor: AppColors.warning,
        onPressed: onUndo,
      ),
      duration: const Duration(seconds: 6),
    );
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          action: action,
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  /// Confirmación destructiva. Devuelve true si el usuario aceptó.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Eliminar',
    String cancelLabel = 'Cancelar',
    bool destructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelLabel,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? AppColors.danger : context.colors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
