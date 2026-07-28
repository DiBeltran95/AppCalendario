import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../agenda/agenda_panel.dart';
import '../calendar/calendar_view.dart';
import '../cycle/cycle_panel.dart';
import '../finance/finance_panel.dart';
import '../habits/habits_panel.dart';
import '../notes/notes_panel.dart';
import 'app_header.dart';
import 'dashboard_controller.dart';
import 'module_nav_bar.dart';

/// Pantalla principal.
///
/// El calendario vive aquí y **no se reconstruye** al cambiar de módulo: lo
/// único que cambia son los indicadores de las celdas y el panel inferior.
/// Ese panel se puede arrastrar hasta ocupar la pantalla, que era el problema
/// de la versión web (una sola columna infinita de scroll).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _collapsed = 0.42;
  static const double _expanded = 0.92;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final module = ref.watch(activeModuleProvider);
    final state = ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: const AppHeader(),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
        color: colors.accent,
        backgroundColor: colors.bgTertiary,
        child: Stack(
          children: [
            // Capa fija: el calendario. Va dentro de un scroll físico mínimo
            // para que el pull-to-refresh tenga de dónde agarrarse.
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                const CalendarView(),
                if (state.error != null) _ErrorBar(message: state.error!),
                // Espacio para que el panel no tape el final del calendario.
                SizedBox(height: MediaQuery.sizeOf(context).height * _collapsed),
              ],
            ),

            // Capa arrastrable: el detalle del módulo activo.
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _collapsed,
              minChildSize: 0.16,
              maxChildSize: _expanded,
              snap: true,
              snapSizes: const [0.16, _collapsed, _expanded],
              builder: (context, scrollController) => _Panel(
                module: module,
                scrollController: scrollController,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ModuleNavBar(
        modules: AppModule.values,
        active: module,
        onSelect: (m) => ref.read(activeModuleProvider.notifier).select(m),
      ),
    );
  }
}

/// Contenedor del panel inferior, con el asa de arrastre y el contenido del
/// módulo. El contenido se intercambia con un fundido cruzado, que es la
/// transición correcta entre pares del mismo nivel.
class _Panel extends StatelessWidget {
  const _Panel({required this.module, required this.scrollController});

  final AppModule module;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      duration: AppMotion.scale(context, AppMotion.emphasized),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Asa de arrastre.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textTertiary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.scale(context, AppMotion.standard),
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.98, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(module),
                child: switch (module) {
                  AppModule.agenda =>
                    AgendaPanel(scrollController: scrollController),
                  AppModule.finance =>
                    FinancePanel(scrollController: scrollController),
                  AppModule.cycle =>
                    CyclePanel(scrollController: scrollController),
                  AppModule.notes =>
                    NotesPanel(scrollController: scrollController),
                  AppModule.habits =>
                    HabitsPanel(scrollController: scrollController),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends ConsumerWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(dashboardControllerProvider.notifier).load(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
