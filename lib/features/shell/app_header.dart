import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../auth/auth_controller.dart';
import '../search/corporate_search_sheet.dart';
import '../shell/dashboard_controller.dart';

/// Cabecera de la app: identidad del módulo activo y accesos rápidos.
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final module = ref.watch(activeModuleProvider);
    final canSearch = ref.watch(canUseCorporateSearchProvider);

    return AppBar(
      toolbarHeight: 58,
      titleSpacing: AppSpacing.lg,
      title: Row(
        children: [
          // El icono del módulo cambia con un giro corto, para que se note que
          // cambió el contexto sin robar protagonismo.
          AnimatedSwitcher(
            duration: AppMotion.scale(context, AppMotion.standard),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: 0.85, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Container(
              key: ValueKey(module),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(module.icon, size: 18, color: colors.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.scale(context, AppMotion.standard),
              child: Text(
                module.title,
                key: ValueKey(module),
                style: text.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (canSearch)
          IconButton(
            tooltip: 'Buscar afiliado o empresa',
            onPressed: () => showCorporateSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => context.push(Routes.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
