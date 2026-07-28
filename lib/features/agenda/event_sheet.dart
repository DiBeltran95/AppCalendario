import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/event.dart';
import '../../data/repositories/events_repository.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/currency_field.dart';
import '../../shared/widgets/option_picker.dart';
import '../shell/dashboard_controller.dart';
import 'event_categories.dart';

/// Abre el formulario de evento (nuevo o edición).
Future<void> showEventSheet(
  BuildContext context, {
  required String dateStr,
  CalendarEvent? event,
}) {
  return showAppSheet(
    context,
    builder: (context) => _EventSheet(dateStr: dateStr, event: event),
  );
}

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({required this.dateStr, this.event});

  final String dateStr;
  final CalendarEvent? event;

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _costController = TextEditingController();

  // Campos exclusivos de cumpleaños.
  final _birthYearController = TextEditingController();
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();

  String _category = 'reunion';
  TimeOfDay? _time;
  EventFrequency _frequency = EventFrequency.once;
  TxKind _txKind = TxKind.none;
  String _paymentStatus = 'pendiente';

  /// Al editar una ocurrencia de una serie, decide si se aplica a todas.
  bool _applyToSeries = false;

  bool _saving = false;

  bool get _isEdit => widget.event != null;
  bool get _isBirthday => _category == EventCategory.birthdayValue;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController.text = event.titulo;
      _locationController.text = event.ubicacion;
      CurrencyField.setValue(_costController, event.costo);
      _category = event.categoria;
      _frequency = event.frecuencia;
      _txKind = event.tipoTransaccion;
      _paymentStatus = event.estadoPago;

      final hora = event.hora;
      if (hora != null && hora.length >= 5) {
        _time = TimeOfDay(
          hour: int.tryParse(hora.substring(0, 2)) ?? 0,
          minute: int.tryParse(hora.substring(3, 5)) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _costController.dispose();
    _birthYearController.dispose();
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final repo = ref.read(eventsRepositoryProvider);

    try {
      if (_isBirthday && !_isEdit) {
        // Los cumpleaños viven en su propia tabla, no en `eventos`.
        await repo.createBirthday(
          nombre: _titleController.text.trim(),
          fecha: widget.dateStr,
          anioNacimiento: int.tryParse(_birthYearController.text.trim()),
          mensaje: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
          telefono: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );
      } else if (_isEdit) {
        await repo.update(
          id: widget.event!.id,
          titulo: _titleController.text.trim(),
          fecha: widget.dateStr,
          hora: _formatTime(),
          categoria: _category,
          ubicacion: _locationController.text.trim(),
          frecuencia: _frequency,
          costo: CurrencyField.valueOf(_costController),
          tipoTransaccion: _txKind,
          estadoPago: _paymentStatus,
          scope: _applyToSeries ? SeriesScope.future : SeriesScope.instance,
        );
      } else {
        await repo.create(
          titulo: _titleController.text.trim(),
          fecha: widget.dateStr,
          hora: _formatTime(),
          categoria: _category,
          ubicacion: _locationController.text.trim(),
          frecuencia: _frequency,
          costo: CurrencyField.valueOf(_costController),
          tipoTransaccion: _txKind,
          estadoPago: _paymentStatus,
        );
      }

      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        _isEdit ? 'Evento actualizado' : 'Evento creado',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  String? _formatTime() {
    final time = _time;
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return AppSheetScaffold(
      title: _isEdit ? 'Editar evento' : 'Nuevo evento',
      subtitle: AppDate.weekdayLong(widget.dateStr),
      icon: EventCategory.resolve(_category).icon,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        confirmLabel: _isEdit ? 'Actualizar' : 'Crear',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerField<String>(
              label: 'Categoría',
              value: _category,
              searchable: true,
              options: [
                for (final c in EventCategory.all)
                  PickerOption(value: c.value, label: c.label, icon: c.icon),
              ],
              onChanged: (v) => setState(() {
                _category = v;
                // El arriendo casi siempre es un gasto mensual: lo damos hecho.
                if (v == 'arriendo') {
                  _txKind = TxKind.expense;
                  _frequency = EventFrequency.monthly;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: _isBirthday ? 'Nombre del cumpleañero' : 'Título',
              controller: _titleController,
              icon: _isBirthday
                  ? Icons.person_outline_rounded
                  : Icons.title_rounded,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 255,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Escribe un título' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            // El formulario cambia según sea cumpleaños o evento normal.
            AnimatedSize(
              duration: AppMotion.scale(context, AppMotion.standard),
              curve: AppMotion.emphasizedCurve,
              alignment: Alignment.topCenter,
              child: _isBirthday
                  ? _buildBirthdayFields(context)
                  : _buildEventFields(context),
            ),

            if (_isEdit && widget.event!.isRecurring) ...[
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile.adaptive(
                value: _applyToSeries,
                onChanged: (v) => setState(() => _applyToSeries = v),
                contentPadding: EdgeInsets.zero,
                title: Text('Aplicar a toda la serie', style: text.titleSmall),
                subtitle: Text(
                  'Afecta a esta fecha y a todas las siguientes',
                  style: text.bodySmall,
                ),
                activeThumbColor: colors.accent,
              ),
            ],

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayFields(BuildContext context) {
    return Column(
      key: const ValueKey('birthday'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Año de nacimiento',
          controller: _birthYearController,
          icon: Icons.cake_rounded,
          hint: 'Opcional',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Mensaje',
          controller: _messageController,
          icon: Icons.message_rounded,
          hint: 'Felicidades…',
          maxLength: 1000,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Teléfono',
          controller: _phoneController,
          icon: Icons.phone_rounded,
          hint: 'Opcional',
          keyboardType: TextInputType.phone,
          maxLength: 50,
        ),
      ],
    );
  }

  Widget _buildEventFields(BuildContext context) {
    final colors = context.colors;

    return Column(
      key: const ValueKey('event'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimeField(
          time: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: 'Ubicación',
          controller: _locationController,
          icon: Icons.place_outlined,
          hint: 'Opcional',
          maxLength: 255,
        ),
        const SizedBox(height: AppSpacing.lg),

        PickerField<EventFrequency>(
          label: 'Repetición',
          value: _frequency,
          options: [
            for (final f in EventFrequency.values)
              PickerOption(
                value: f,
                label: f.label,
                icon: f == EventFrequency.once
                    ? Icons.looks_one_rounded
                    : Icons.repeat_rounded,
              ),
          ],
          onChanged: (v) => setState(() => _frequency = v),
        ),
        const SizedBox(height: AppSpacing.lg),

        PickerField<TxKind>(
          label: 'Movimiento de dinero',
          value: _txKind,
          options: const [
            PickerOption(
              value: TxKind.none,
              label: 'Ninguno',
              subtitle: 'Evento general',
              icon: Icons.block_rounded,
            ),
            PickerOption(
              value: TxKind.expense,
              label: 'Gasto',
              subtitle: 'Factura, cita, compra',
              icon: Icons.trending_down_rounded,
              color: AppColors.expense,
            ),
            PickerOption(
              value: TxKind.income,
              label: 'Ingreso',
              subtitle: 'Cobro, pago recibido',
              icon: Icons.trending_up_rounded,
              color: AppColors.income,
            ),
          ],
          onChanged: (v) => setState(() => _txKind = v),
        ),

        // El importe y el estado solo tienen sentido si hay dinero de por medio.
        AnimatedSize(
          duration: AppMotion.scale(context, AppMotion.standard),
          curve: AppMotion.emphasizedCurve,
          alignment: Alignment.topCenter,
          child: _txKind.isFinancial
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CurrencyField(
                        controller: _costController,
                        accent: _txKind == TxKind.income
                            ? AppColors.income
                            : AppColors.expense,
                        validator: (v) =>
                            AppCurrency.parseInput(v ?? '') <= 0
                                ? 'Escribe un valor'
                                : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PickerField<String>(
                        label: 'Estado',
                        value: _paymentStatus,
                        options: [
                          PickerOption(
                            value: 'pendiente',
                            label: 'Pendiente',
                            icon: Icons.hourglass_empty_rounded,
                            color: AppColors.warning,
                          ),
                          PickerOption(
                            value: 'pagado',
                            label: _txKind == TxKind.income
                                ? 'Recibido'
                                : 'Pagado',
                            icon: Icons.check_circle_rounded,
                            color: colors.success,
                          ),
                        ],
                        onChanged: (v) => setState(() => _paymentStatus = v),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Selector de hora, con la opción de dejarlo en "todo el día".
class _TimeField extends StatelessWidget {
  const _TimeField({required this.time, required this.onChanged});

  final TimeOfDay? time;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HORA',
          style: text.labelSmall?.copyWith(
            color: colors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Material(
                color: colors.bgTertiary,
                borderRadius: BorderRadius.circular(AppRadius.input),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time ?? TimeOfDay.now(),
                    );
                    if (picked != null) onChanged(picked);
                  },
                  child: Container(
                    height: 54,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 20, color: colors.textTertiary),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          time == null
                              ? 'Todo el día'
                              : time!.format(context),
                          style: text.bodyLarge?.copyWith(
                            color: time == null
                                ? colors.textTertiary
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.clear_rounded, size: 20),
                color: colors.textSecondary,
                tooltip: 'Quitar hora',
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          time == null
              ? 'Sin hora te avisamos a las 7:00 a. m. en el resumen del día.'
              : 'Te recordamos 30 minutos antes y a la hora exacta.',
          style: text.bodySmall?.copyWith(
            fontSize: 11,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
