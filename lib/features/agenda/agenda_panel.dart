import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/event.dart';
import '../../data/repositories/events_repository.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/animated_counter.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/panel_parts.dart';
import '../../shared/widgets/skeleton.dart';
import '../calendar/calendar_day.dart';
import '../calendar/month_highlights.dart';
import '../shell/dashboard_controller.dart';
import 'event_categories.dart';
import 'event_sheet.dart';
import 'whatsapp_preview.dart';

/// Panel del módulo Agenda: detalle del día o próximos eventos del mes.
class AgendaPanel extends ConsumerWidget {
  const AgendaPanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final day = state.dayFor(state.selectedDay);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        HintBar(text: AppModule.agenda.hint),
        const SizedBox(height: AppSpacing.lg),

        if (state.loading)
          const ListSkeleton(count: 3)
        else if (day != null)
          ..._buildDayDetail(context, ref, day, controller)
        else
          ..._buildMonthOverview(context, ref, state),
      ],
    );
  }

  // --- Día seleccionado ---

  List<Widget> _buildDayDetail(
    BuildContext context,
    WidgetRef ref,
    CalendarDay day,
    DashboardController controller,
  ) {
    final subtitleParts = <String>[
      if (day.hasEvents) '${day.events.length} evento(s)',
      if (day.hasBirthdays) '${day.birthdays.length} cumpleaños',
    ];

    return [
      SelectedDayHeader(
        dateStr: day.dateStr,
        subtitle: subtitleParts.isEmpty ? 'Sin compromisos' : subtitleParts.join(' · '),
        icon: day.holiday != null
            ? Icons.celebration_rounded
            : day.hasBirthdays
                ? Icons.cake_rounded
                : Icons.event_rounded,
        onClear: controller.clearSelection,
      ),
      const SizedBox(height: AppSpacing.lg),

      if (day.holiday != null) ...[
        _InfoCard(
          icon: Icons.celebration_rounded,
          color: AppColors.danger,
          title: day.holiday!.displayName,
          subtitle: 'Festivo nacional · Día no laboral',
        ),
        const SizedBox(height: AppSpacing.md),
      ],

      if (day.importantDay != null) ...[
        _InfoCard(
          icon: Icons.star_rounded,
          color: AppColors.gold,
          title: day.importantDay!.nombre,
          subtitle: day.importantDay!.descripcion ??
              day.importantDay!.categoria ??
              'Día especial',
        ),
        const SizedBox(height: AppSpacing.md),
      ],

      if (day.hasEvents) ...[
        const SectionTitle(title: 'Eventos', icon: Icons.schedule_rounded),
        for (var i = 0; i < day.events.length; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _EventCard(event: day.events[i], dateStr: day.dateStr),
            ),
          ),
      ],

      if (day.hasBirthdays) ...[
        const SizedBox(height: AppSpacing.sm),
        const SectionTitle(title: 'Cumpleaños', icon: Icons.cake_rounded),
        for (var i = 0; i < day.birthdays.length; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _BirthdayCard(
                birthday: day.birthdays[i],
                year: DateTime.now().year,
              ),
            ),
          ),
      ],

      if (!day.hasEvents &&
          !day.hasBirthdays &&
          day.holiday == null &&
          day.importantDay == null)
        EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Día libre',
          message: 'No tienes eventos ni cumpleaños programados para este día.',
          actionLabel: 'Crear evento',
          onAction: () => showEventSheet(context, dateStr: day.dateStr),
          compact: true,
        ),

      const SizedBox(height: AppSpacing.lg),
      PanelActionButton(
        label: 'Nuevo evento',
        icon: Icons.add_rounded,
        onPressed: () => showEventSheet(context, dateStr: day.dateStr),
      ),
    ];
  }

  // --- Sin día seleccionado: resumen del mes ---

  List<Widget> _buildMonthOverview(
    BuildContext context,
    WidgetRef ref,
    DashboardState state,
  ) {
    final monthEvents = state.monthData.events;
    final birthdaysThisMonth = state.bootstrap.cumpleanos.where((b) {
      final month = int.tryParse(b.monthDay.split('-').first);
      return month == state.month;
    }).length;
    final holidaysThisMonth =
        state.holidays.where((h) => h.date.startsWith(state.monthPrefix)).length;

    final hasAnything =
        monthEvents.isNotEmpty || birthdaysThisMonth > 0 || holidaysThisMonth > 0;

    return [
      Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Eventos',
              value: monthEvents.length.toDouble(),
              icon: Icons.event_rounded,
              integer: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _MetricTile(
              label: 'Cumpleaños',
              value: birthdaysThisMonth.toDouble(),
              icon: Icons.cake_rounded,
              integer: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _MetricTile(
              label: 'Festivos',
              value: holidaysThisMonth.toDouble(),
              icon: Icons.celebration_rounded,
              integer: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),

      // Aquí se ve QUIÉN cumple años y QUÉ festivo cae, con nombre propio.
      if (hasAnything)
        const MonthHighlights(module: AppModule.agenda)
      else
        const EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Mes despejado',
          message:
              'No hay eventos, cumpleaños ni festivos. Mantén pulsado un día del calendario para crear algo.',
          compact: true,
        ),
    ];
  }
}

/// Tarjeta de un evento con acciones y el recordatorio de WhatsApp.
class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({required this.event, required this.dateStr});

  final CalendarEvent event;
  final String dateStr;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _showReminder = false;
  bool _busy = false;

  Future<void> _delete() async {
    final event = widget.event;
    final scope = event.isRecurring
        ? await _askScope(context)
        : SeriesScope.instance;
    if (scope == null) return;

    if (!mounted) return;
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Eliminar evento',
      message: scope == SeriesScope.future
          ? 'Se eliminarán esta fecha y todas las siguientes de la serie.'
          : '¿Eliminar "${event.titulo}"?',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await ref.read(eventsRepositoryProvider).delete(event.id, scope: scope);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (mounted) AppFeedback.showSuccess(context, 'Evento eliminado');
    } on ApiException catch (e) {
      if (mounted) AppFeedback.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<SeriesScope?> _askScope(BuildContext context) {
    return showDialog<SeriesScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Este evento se repite'),
        content: Text(
          '¿Qué quieres eliminar?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, SeriesScope.instance),
            child: const Text('Solo esta fecha'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, SeriesScope.future),
            child: const Text('Esta y las siguientes'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePayment() async {
    final event = widget.event;
    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .togglePayment(event.id, markAsPaid: event.isPending);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          event.isPending ? 'Marcado como pagado' : 'Marcado como pendiente',
        );
      }
    } on ApiException catch (e) {
      if (mounted) AppFeedback.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final event = widget.event;
    final category = EventCategory.resolve(event.categoria);

    final accent = event.isFinancial
        ? (event.tipoTransaccion == TxKind.income
            ? AppColors.income
            : AppColors.expense)
        : colors.accent;

    return AppCard(
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.bgHover,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Column(
                  children: [
                    Icon(category.icon, size: 15, color: accent),
                    const SizedBox(height: 2),
                    Text(
                      event.shortTime ?? '--:--',
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.titulo,
                      style: text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event.ubicacion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 12, color: colors.textTertiary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              event.ubicacion,
                              style: text.bodySmall?.copyWith(fontSize: 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (event.isRecurring)
                          StatusPill(
                            label: event.frecuencia.label,
                            color: colors.textSecondary,
                            icon: Icons.repeat_rounded,
                          ),
                        if (event.isFinancial)
                          StatusPill(
                            label: AppCurrency.format(event.costo),
                            color: accent,
                          ),
                        if (event.isFinancial)
                          StatusPill(
                            label: event.isPaid ? 'Pagado' : 'Pendiente',
                            color: event.isPaid
                                ? colors.success
                                : AppColors.warning,
                            icon: event.isPaid
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_empty_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (event.isFinancial)
                _IconAction(
                  icon: event.isPaid
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                  tooltip: event.isPaid
                      ? 'Marcar como pendiente'
                      : 'Marcar como pagado',
                  color: event.isPaid ? colors.textSecondary : colors.success,
                  onTap: _busy ? null : _togglePayment,
                ),
              _IconAction(
                icon: Icons.chat_rounded,
                tooltip: 'Recordatorio de WhatsApp',
                color: _showReminder ? colors.accent : colors.textSecondary,
                onTap: () => setState(() => _showReminder = !_showReminder),
              ),
              const Spacer(),
              _IconAction(
                icon: Icons.edit_rounded,
                tooltip: 'Editar',
                color: colors.textSecondary,
                onTap: _busy
                    ? null
                    : () => showEventSheet(
                          context,
                          dateStr: widget.dateStr,
                          event: event,
                        ),
              ),
              _IconAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                color: AppColors.danger,
                onTap: _busy ? null : _delete,
              ),
            ],
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _showReminder
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: WhatsAppPreview(event: event),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _BirthdayCard extends ConsumerWidget {
  const _BirthdayCard({required this.birthday, required this.year});

  final Birthday birthday;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final age = birthday.ageOn(year);

    return AppCard(
      accent: const Color(0xFFF06292),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Text('🎂', style: TextStyle(fontSize: 26)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(birthday.nombre, style: text.titleSmall),
                if (age != null)
                  Text('Cumple $age años', style: text.bodySmall),
                if (birthday.mensaje != null && birthday.mensaje!.isNotEmpty)
                  Text(
                    '"${birthday.mensaje}"',
                    style: text.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          _IconAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: AppColors.danger,
            onTap: () async {
              final ok = await AppFeedback.confirm(
                context,
                title: 'Eliminar cumpleaños',
                message: '¿Eliminar el cumpleaños de ${birthday.nombre}?',
              );
              if (!ok) return;
              try {
                await ref
                    .read(eventsRepositoryProvider)
                    .deleteBirthday(birthday.id);
                await ref.read(dashboardControllerProvider.notifier).refresh();
                if (context.mounted) {
                  AppFeedback.showSuccess(context, 'Cumpleaños eliminado');
                }
              } on ApiException catch (e) {
                if (context.mounted) AppFeedback.showError(context, e.message);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      accent: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.integer = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final accent = colors.accent;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: AppSpacing.sm),
          AnimatedCounter(
            value: value,
            formatter: integer
                ? (v) => v.round().toString()
                : AppCurrency.format,
            style: text.headlineSmall?.copyWith(color: accent),
          ),
          Text(label, style: text.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
