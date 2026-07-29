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

  /// Panel en reposo: el calendario manda.
  static const double _collapsed = 0.42;

  /// Panel con un día seleccionado. Deja ver un par de semanas del calendario
  /// —para no perder de vista qué día se tocó— y el detalle completo debajo.
  static const double _detail = 0.66;

  static const double _expanded = 0.92;

  /// Scroll interno del panel, para volver arriba al cambiar de día.
  ScrollController? _panelScroll;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// Sube el panel hasta que el detalle del día quede a la vista.
  ///
  /// Sin esto el detalle se dibujaba igual, pero por debajo del pliegue: al
  /// tocar un día parecía que no pasaba nada y había que arrastrar a mano.
  void _revealDetail() {
    if (!_sheetController.isAttached) return;

    // El detalle empieza arriba del todo.
    final scroll = _panelScroll;
    if (scroll != null && scroll.hasClients && scroll.offset > 0) {
      scroll.jumpTo(0);
    }

    // Si el usuario ya lo tenía más arriba, se respeta su posición.
    if (_sheetController.size >= _detail - 0.01) return;

    _sheetController.animateTo(
      _detail,
      duration: AppMotion.emphasized,
      curve: AppMotion.emphasizedCurve,
    );
  }

  /// Al quitar la selección, el panel vuelve a dejar sitio al calendario.
  void _collapseSheet() {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size <= _collapsed + 0.01) return;

    _sheetController.animateTo(
      _collapsed,
      duration: AppMotion.emphasized,
      curve: AppMotion.emphasizedCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final module = ref.watch(activeModuleProvider);
    final state = ref.watch(dashboardControllerProvider);

    // Tocar un día debe mostrar su detalle, como en la versión web.
    ref.listen<String?>(
      dashboardControllerProvider.select((s) => s.selectedDay),
      (previous, next) {
        if (next != null) {
          _revealDetail();
        } else {
          _collapseSheet();
        }
      },
    );

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
              snapSizes: const [0.16, _collapsed, _detail, _expanded],
              builder: (context, scrollController) {
                // Se guarda para poder devolver el panel al principio cuando
                // se selecciona otro día.
                _panelScroll = scrollController;
                return _Panel(
                  module: module,
                  scrollController: scrollController,
                  hasSelection: state.selectedDay != null,
                );
              },
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
  const _Panel({
    required this.module,
    required this.scrollController,
    this.hasSelection = false,
  });

  final AppModule module;
  final ScrollController scrollController;

  /// Con un día seleccionado el asa se tiñe del color del módulo: señala que
  /// el panel trae contenido de ese día.
  final bool hasSelection;

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
            child: AnimatedContainer(
              duration: AppMotion.scale(context, AppMotion.standard),
              curve: AppMotion.emphasizedCurve,
              width: hasSelection ? 52 : 40,
              height: 4,
              decoration: BoxDecoration(
                color: hasSelection ? colors.accent : colors.textTertiary,
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
