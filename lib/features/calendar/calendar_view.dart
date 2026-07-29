import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/widgets/animated_counter.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/skeleton.dart';
import '../shell/dashboard_controller.dart';
import 'day_actions_sheet.dart';
import 'day_cell.dart';

/// Calendario mensual.
///
/// Es un [PageView] "infinito": cada página es un mes, así que cambiar de mes
/// es un gesto natural en lugar de dos flechitas. La página central se
/// recentra tras cada salto para que el desplazamiento no tenga fin.
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  /// Alto de una celda. Da sitio al número y a dos etiquetas de contenido.
  static const double cellHeight = 60;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  /// Página inicial arbitraria: da margen para ~800 años en cada dirección.
  static const int _initialPage = 10000;

  late final PageController _controller = PageController(
    initialPage: _initialPage,
  );

  /// Mes de referencia de la página [_initialPage].
  late final DateTime _anchor = () {
    final state = ref.read(dashboardControllerProvider);
    return DateTime(state.year, state.month);
  }();

  int _page = _initialPage;
  bool _forward = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final offset = page - _initialPage;
    return DateTime(_anchor.year, _anchor.month + offset);
  }

  void _onPageChanged(int page) {
    final target = _monthForPage(page);
    setState(() {
      _forward = page > _page;
      _page = page;
    });
    AppFeedback.select();
    ref
        .read(dashboardControllerProvider.notifier)
        .goToMonth(target.year, target.month);
  }

  /// Lleva el PageView al mes que diga el estado, si alguien lo cambió desde
  /// fuera (botones de navegación, "hoy", etc.).
  void _syncTo(int year, int month) {
    final current = _monthForPage(_page);
    if (current.year == year && current.month == month) return;

    final delta = (year - _anchor.year) * 12 + (month - _anchor.month);
    final target = _initialPage + delta;
    if (!_controller.hasClients) return;

    _controller.animateToPage(
      target,
      duration: AppMotion.emphasized,
      curve: AppMotion.emphasizedCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    // Cambios de mes que no vienen del swipe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTo(state.year, state.month);
    });

    return Column(
      children: [
        _MonthHeader(
          year: state.year,
          month: state.month,
          forward: _forward,
          refreshing: state.refreshing,
          onPrevious: controller.goToPreviousMonth,
          onNext: controller.goToNextMonth,
          onToday: controller.goToToday,
        ),
        const _WeekdayHeader(),
        SizedBox(
          height: _gridHeight(state.year, state.month),
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) {
              final month = _monthForPage(page);
              final isCurrent =
                  month.year == state.year && month.month == state.month;

              // Solo el mes visible tiene datos cargados; los vecinos se
              // dibujan como esqueleto mientras el swipe está en curso.
              if (!isCurrent || state.loading) return const CalendarSkeleton();

              return _MonthGrid(key: ValueKey('${state.year}-${state.month}'));
            },
          ),
        ),
      ],
    );
  }

  /// Alto exacto de la grilla del mes, para que no quede hueco muerto.
  double _gridHeight(int year, int month) {
    final first = AppDate.firstWeekdayIndex(year, month);
    final days = AppDate.daysInMonth(year, month);
    final rows = ((first + days) / 7).ceil();
    return rows * CalendarView.cellHeight + (rows - 1) * 5 + AppSpacing.sm;
  }
}

/// Grilla de un mes, con entrada escalonada por filas.
class _MonthGrid extends ConsumerStatefulWidget {
  const _MonthGrid({super.key});

  @override
  ConsumerState<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends ConsumerState<_MonthGrid>
    with SingleTickerProviderStateMixin {
  // Un solo controlador para las ~42 celdas: crear uno por celda sería caro
  // y aquí basta con desfasar la misma animación por índice.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final module = ref.watch(activeModuleProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final days = state.buildDays();
    final blanks = AppDate.firstWeekdayIndex(state.year, state.month);
    final reduced = MediaQuery.disableAnimationsOf(context);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: blanks + days.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        mainAxisExtent: CalendarView.cellHeight,
      ),
      itemBuilder: (context, index) {
        if (index < blanks) return const SizedBox.shrink();

        final day = days[index - blanks];
        final cell = DayCell(
          data: day,
          module: module,
          selected: state.selectedDay == day.dateStr,
          onTap: () {
            AppFeedback.select();
            controller.selectDay(day.dateStr);
          },
          onLongPress: () {
            AppFeedback.light();
            controller.selectDay(day.dateStr);
            showDayActions(context, ref, day.dateStr);
          },
        );

        if (reduced) return cell;

        // Las celdas aparecen por filas, de arriba abajo.
        final row = index ~/ 7;
        final start = (row * 0.07).clamp(0.0, 0.6);
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
              curve: AppMotion.enter),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Opacity(
            opacity: animation.value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - animation.value)),
              child: child,
            ),
          ),
          child: cell,
        );
      },
    );
  }
}

/// Cabecera con el mes, el año que rueda y los controles de navegación.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.year,
    required this.month,
    required this.forward,
    required this.refreshing,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final int year;
  final int month;
  final bool forward;
  final bool refreshing;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // Mes y año a la izquierda, con jerarquía tipográfica clara.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: AppMotion.scale(context, AppMotion.standard),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(forward ? 0.2 : -0.2, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      AppDate.monthNames[month - 1],
                      key: ValueKey(month),
                      style: text.headlineSmall?.copyWith(
                        fontSize: 21,
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                RollingNumber(
                  value: year,
                  forward: forward,
                  style: text.titleMedium?.copyWith(
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (refreshing) ...[
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.accent.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Controles agrupados en una sola pastilla: menos ruido visual.
          Container(
            decoration: BoxDecoration(
              color: colors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
                AnimatedSize(
                  duration: AppMotion.scale(context, AppMotion.standard),
                  child: isCurrentMonth
                      ? const SizedBox(width: 0)
                      : _NavButton(
                          icon: Icons.today_rounded,
                          onTap: onToday,
                          highlighted: true,
                        ),
                ),
                _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () {
        AppFeedback.select();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: highlighted ? 17 : 20,
          color: highlighted ? colors.accent : colors.textSecondary,
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  AppDate.weekdayInitials[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: (i == 0 || i == 6)
                            ? colors.accent.withValues(alpha: 0.75)
                            : colors.textTertiary,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
