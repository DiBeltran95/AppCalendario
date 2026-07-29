import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_motion.dart';
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
import '../calendar/day_detail_header.dart';
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
        if (state.loading)
          const ListSkeleton(count: 3)
        else if (day != null)
          ..._buildDayDetail(context, ref, day, controller)
        else ...[
          HintBar(text: AppModule.agenda.hint),
          const SizedBox(height: AppSpacing.lg),
          ..._buildMonthOverview(context, ref, state),
        ],
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
    final colors = context.colors;
    final year = AppDate.parse(day.dateStr).year;
    const pink = Color(0xFFF06292);

    // El color del día lo marca lo más señalado que tenga.
    final tone = day.holiday != null
        ? AppColors.danger
        : day.hasBirthdays
            ? pink
            : day.importantDay != null
                ? AppColors.gold
                : colors.accent;

    return [
      DayDetailHeader(
        dateStr: day.dateStr,
        accent: tone,
        onClear: controller.clearSelection,
        emptyLabel: 'Día libre: sin eventos ni cumpleaños.',
        // Las pastillas dicen QUÉ TIPO de día es; los nombres concretos van en
        // las fichas de abajo, para no repetir lo mismo dos veces.
        chips: [
          if (day.holiday != null)
            const DaySummaryChip(
              label: 'Festivo',
              color: AppColors.danger,
              emoji: '🎉',
            ),
          if (day.importantDay != null)
            const DaySummaryChip(
              label: 'Día especial',
              color: AppColors.gold,
              emoji: '★',
            ),
          if (day.hasBirthdays)
            DaySummaryChip(
              label: day.birthdays.length == 1
                  ? '1 cumpleaños'
                  : '${day.birthdays.length} cumpleaños',
              color: pink,
              emoji: '🎂',
            ),
          if (day.hasEvents)
            DaySummaryChip(
              label: day.events.length == 1
                  ? '1 evento'
                  : '${day.events.length} eventos',
              color: colors.accent,
              icon: Icons.event_rounded,
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),

      if (day.holiday != null) ...[
        FadeSlideIn(
          child: _DayNoteCard(
            icon: Icons.celebration_rounded,
            color: AppColors.danger,
            title: day.holiday!.displayName,
            subtitle: 'Festivo nacional',
            badge: 'Día no laboral',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],

      if (day.importantDay != null) ...[
        FadeSlideIn(
          index: 1,
          child: _DayNoteCard(
            icon: Icons.star_rounded,
            color: AppColors.gold,
            title: day.importantDay!.nombre,
            subtitle: day.importantDay!.descripcion ??
                day.importantDay!.categoria ??
                'Día especial',
            badge: day.importantDay!.categoria,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],

      if (day.hasBirthdays) ...[
        SectionTitle(
          title: 'Cumpleaños',
          icon: Icons.cake_rounded,
          color: pink,
          trailing: _CountBadge(value: day.birthdays.length, color: pink),
        ),
        for (var i = 0; i < day.birthdays.length; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _BirthdayCard(birthday: day.birthdays[i], year: year),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],

      if (day.hasEvents) ...[
        SectionTitle(
          title: 'Eventos',
          icon: Icons.schedule_rounded,
          trailing: _CountBadge(value: day.events.length, color: colors.accent),
        ),
        for (var i = 0; i < day.events.length; i++)
          FadeSlideIn(
            index: i,
            child: _EventCard(
              event: day.events[i],
              dateStr: day.dateStr,
              isLast: i == day.events.length - 1,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
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
        )
      else ...[
        const SizedBox(height: AppSpacing.sm),
        PanelActionButton(
          label: 'Nuevo evento',
          icon: Icons.add_rounded,
          onPressed: () => showEventSheet(context, dateStr: day.dateStr),
        ),
      ],
    ];
  }

  // --- Sin día seleccionado: resumen del mes ---

  List<Widget> _buildMonthOverview(
    BuildContext context,
    WidgetRef ref,
    DashboardState state,
  ) {
    final today = AppDate.today();
    final upcoming = state.monthData.events
        .where((e) => e.fecha.compareTo(today) >= 0)
        .toList()
      ..sort((a, b) {
        final byDate = a.fecha.compareTo(b.fecha);
        if (byDate != 0) return byDate;
        return (a.hora ?? '').compareTo(b.hora ?? '');
      });

    final monthEvents = state.monthData.events;
    final birthdaysThisMonth = state.bootstrap.cumpleanos.where((b) {
      final month = int.tryParse(b.monthDay.split('-').first);
      return month == state.month;
    }).length;

    return [
      Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Eventos del mes',
              value: monthEvents.length.toDouble(),
              icon: Icons.event_rounded,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MetricTile(
              label: 'Cumpleaños',
              value: birthdaysThisMonth.toDouble(),
              icon: Icons.cake_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),

      if (upcoming.isEmpty)
        const EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Nada por delante',
          message:
              'No quedan eventos este mes. Mantén pulsado un día del calendario para crear uno.',
          compact: true,
        )
      else ...[
        const SectionTitle(
          title: 'Próximos eventos',
          icon: Icons.upcoming_rounded,
        ),
        for (var i = 0; i < upcoming.length && i < 8; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UpcomingTile(
                event: upcoming[i],
                onTap: () => ref
                    .read(dashboardControllerProvider.notifier)
                    .selectDay(upcoming[i].fecha),
              ),
            ),
          ),
      ],
    ];
  }
}

/// Contador junto al título de una sección.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Ficha de festivo o día importante.
class _DayNoteCard extends StatelessWidget {
  const _DayNoteCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall?.copyWith(fontSize: 12)),
                if (badge != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  StatusPill(
                    label: badge!,
                    color: color,
                    icon: Icons.event_available_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de cumpleaños: iniciales, edad grande y felicitación por WhatsApp.
class _BirthdayCard extends ConsumerWidget {
  const _BirthdayCard({required this.birthday, required this.year});

  final Birthday birthday;
  final int year;

  static const Color _pink = Color(0xFFF06292);

  String get _initials {
    final parts = birthday.nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _congratulate(BuildContext context) async {
    final message = birthday.mensaje?.isNotEmpty == true
        ? birthday.mensaje!
        : '¡Feliz cumpleaños, ${birthday.nombre.split(' ').first}! 🎂';

    // Con teléfono se abre el chat de esa persona; sin él, el selector.
    final phone = birthday.telefono?.replaceAll(RegExp(r'\D'), '') ?? '';
    final uri = Uri.parse(
      phone.isEmpty
          ? 'https://wa.me/?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppFeedback.showError(context, 'No pudimos abrir WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final age = birthday.ageOn(year);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _pink.withValues(alpha: 0.16),
            colors.bgTertiary.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(color: _pink.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar con iniciales: identifica sin necesitar una foto.
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_pink, Color(0xFFAB47BC)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: text.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      birthday.nombre,
                      style: text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (birthday.mensaje?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"${birthday.mensaje}"',
                        style: text.bodySmall?.copyWith(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (age != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Column(
                  children: [
                    AnimatedCounter(
                      value: age.toDouble(),
                      formatter: (v) => v.round().toString(),
                      style: text.displaySmall?.copyWith(
                        fontSize: 32,
                        height: 1,
                        color: _pink,
                      ),
                    ),
                    Text(
                      age == 1 ? 'año' : 'años',
                      style: text.labelSmall?.copyWith(
                        color: _pink.withValues(alpha: 0.8),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _congratulate(context),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('Felicitar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: const Color(0xFF0B141A),
                    minimumSize: const Size(0, 40),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.danger,
                tooltip: 'Eliminar',
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar cumpleaños',
      message: '¿Eliminar el cumpleaños de ${birthday.nombre}?',
    );
    if (!ok) return;

    try {
      await ref.read(eventsRepositoryProvider).deleteBirthday(birthday.id);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Cumpleaños eliminado');
      }
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
    }
  }
}

/// Evento del día, sobre un raíl de tiempo vertical.
class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({
    required this.event,
    required this.dateStr,
    required this.isLast,
  });

  final CalendarEvent event;
  final String dateStr;
  final bool isLast;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _showReminder = false;
  bool _busy = false;

  Color _accentOf(BuildContext context) {
    final event = widget.event;
    if (!event.isFinancial) return context.colors.accent;
    return event.tipoTransaccion == TxKind.income
        ? AppColors.income
        : AppColors.expense;
  }

  Future<void> _delete() async {
    final event = widget.event;
    final scope =
        event.isRecurring ? await _askScope(context) : SeriesScope.instance;
    if (scope == null || !mounted) return;

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
    final accent = _accentOf(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Raíl de tiempo: ancla el evento en el día de un vistazo.
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  event.shortTime ?? '· ·',
                  style: text.labelMedium?.copyWith(
                    color: event.shortTime == null
                        ? colors.textTertiary
                        : colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: colors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: widget.isLast ? 0 : AppSpacing.md,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.bgTertiary,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(category.icon, size: 15, color: accent),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            event.titulo,
                            style: text.titleSmall?.copyWith(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (event.ubicacion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 12, color: colors.textTertiary),
                          const SizedBox(width: 4),
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

                    if (event.isFinancial || event.isRecurring) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
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
                          if (event.isRecurring)
                            StatusPill(
                              label: event.frecuencia.label,
                              color: colors.textSecondary,
                              icon: Icons.repeat_rounded,
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (event.isFinancial)
                          _MiniAction(
                            icon: event.isPaid
                                ? Icons.undo_rounded
                                : Icons.check_circle_outline_rounded,
                            tooltip: event.isPaid
                                ? 'Marcar pendiente'
                                : 'Marcar pagado',
                            color: event.isPaid
                                ? colors.textSecondary
                                : colors.success,
                            onTap: _busy ? null : _togglePayment,
                          ),
                        _MiniAction(
                          icon: Icons.chat_rounded,
                          tooltip: 'Recordatorio de WhatsApp',
                          color: _showReminder
                              ? colors.accent
                              : colors.textSecondary,
                          onTap: () =>
                              setState(() => _showReminder = !_showReminder),
                        ),
                        const Spacer(),
                        _MiniAction(
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
                        _MiniAction(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Eliminar',
                          color: AppColors.danger,
                          onTap: _busy ? null : _delete,
                        ),
                      ],
                    ),

                    AnimatedSize(
                      duration: AppMotion.scale(context, AppMotion.standard),
                      curve: AppMotion.emphasizedCurve,
                      alignment: Alignment.topCenter,
                      child: _showReminder
                          ? Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.sm),
                              child: WhatsAppPreview(event: event),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final date = AppDate.parse(event.fecha);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: text.titleMedium?.copyWith(color: colors.accent),
                ),
                Text(
                  AppDate.monthShort[date.month - 1],
                  style: text.labelSmall?.copyWith(
                    color: colors.accent.withValues(alpha: 0.8),
                    fontSize: 9.5,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  event.shortTime ?? 'Todo el día',
                  style: text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
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
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.accent),
          const SizedBox(height: AppSpacing.sm),
          AnimatedCounter(
            value: value,
            formatter: (v) => v.round().toString(),
            style: text.headlineSmall?.copyWith(color: colors.accent),
          ),
          Text(label, style: text.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
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
      icon: Icon(icon, size: 17),
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: EdgeInsets.zero,
    );
  }
}
