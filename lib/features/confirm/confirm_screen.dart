import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import '../../data/models/finance.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/currency_field.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/loading_button.dart';
import '../../shared/widgets/option_picker.dart';
import '../../shared/widgets/orb_background.dart';

/// Pantalla pública de confirmación de un evento.
///
/// Se abre desde el enlace que viaja en el recordatorio de WhatsApp
/// (`/confirmar/:uuid`). No requiere sesión: el UUID es la autorización.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.uuid});

  final String uuid;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  final _costController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _confirmed = false;
  String? _error;

  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _accounts = const [];
  List<Map<String, dynamic>> _categories = const [];

  bool _registerTransaction = true;
  int? _accountId;
  String _category = 'otros';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.uuid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Enlace de confirmación no válido.';
      });
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getMap(
        '/api/public/events/confirmar/${widget.uuid}',
        authenticated: false,
      );

      _accounts = asMapList(data['cuentas']);
      _categories = asMapList(data['categorias']);
      _applyDefaults(data);

      setState(() {
        _event = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// Valores por defecto, portados de `applyDefaults` en Confirmar.svelte.
  void _applyDefaults(Map<String, dynamic> event) {
    CurrencyField.setValue(_costController, asDouble(event['costo']));

    final eventCategory = asString(event['categoria']);
    final available = _categories.map((c) => asString(c['valor'])).toSet();

    if (available.contains(eventCategory)) {
      _category = eventCategory;
    } else if (const ['moto', 'carro', 'aceite_moto', 'mecanica']
        .contains(eventCategory)) {
      _category = 'transporte';
    } else if (const ['servicios', 'casa', 'arriendo'].contains(eventCategory)) {
      _category = 'servicios';
    } else if (const ['doctor', 'medicamentos', 'dentista']
        .contains(eventCategory)) {
      _category = 'salud';
    } else if (const [
      'cita_amor', 'aniversario', 'matrimonio', 'mesiversario', 'cumpleanos'
    ].contains(eventCategory)) {
      _category = 'entretenimiento';
    } else {
      _category = available.contains('otros')
          ? 'otros'
          : (available.firstOrNull ?? 'otros');
    }

    // Cuenta por defecto: ahorros primero, la tarjeta de crédito de última.
    if (_accounts.isNotEmpty) {
      const priority = {
        'ahorros': 1, 'efectivo': 2, 'corriente': 3, 'cdt': 4, 'otro': 5,
        'tarjeta_credito': 99,
      };
      final sorted = [..._accounts]..sort(
          (a, b) => (priority[asString(a['tipo'])] ?? 50)
              .compareTo(priority[asString(b['tipo'])] ?? 50),
        );
      _accountId = asIntOrNull(sorted.first['id']);
    }
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/api/public/events/confirmar/${widget.uuid}',
        authenticated: false,
        body: {
          'estado': 'pagado',
          'costo': CurrencyField.valueOf(_costController),
          'registrarTransaccion': _registerTransaction,
          'cuentaId': _registerTransaction ? _accountId : null,
          'categoriaTransaccion': _registerTransaction ? _category : null,
        },
      );
      if (!mounted) return;
      AppFeedback.success();
      setState(() => _confirmed = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: OrbBackground(
        colors: [
          colors.accent.withValues(alpha: 0.2),
          AppColors.sky.withValues(alpha: 0.14),
        ],
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedSwitcher(
                  duration: AppMotion.scale(context, AppMotion.emphasized),
                  child: _loading
                      ? const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        )
                      : _error != null
                          ? _ErrorView(key: const ValueKey('error'), message: _error!)
                          : _confirmed
                              ? const _SuccessView(key: ValueKey('success'))
                              : _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final event = _event!;
    final title = asString(event['titulo'], fallback: 'Evento');
    final creator = asString(event['creador']);
    final date = AppDate.normalize(event['fecha']);
    final time = AppDate.shortTime(asStringOrNull(event['hora']));
    final isExpense = asString(event['tipo_transaccion']) != 'ingreso';
    final alreadyPaid = asString(event['estado_pago']) == 'pagado';

    return GlassCard(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.event_available_rounded, size: 44, color: colors.accent),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Confirmación de compromiso',
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          if (creator.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Creado por $creator',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.bgTertiary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${AppDate.weekdayLong(date)}${time == null ? '' : ' · $time'}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          if (alreadyPaid) ...[
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(
                  color: AppColors.income.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.income),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Este compromiso ya fue confirmado.',
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.income),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xl),
            FadeSlideIn(
              index: 1,
              child: CurrencyField(
                controller: _costController,
                label: isExpense ? 'Valor pagado' : 'Valor recibido',
                accent: isExpense ? AppColors.expense : AppColors.income,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_accounts.isNotEmpty) ...[
              SwitchListTile.adaptive(
                value: _registerTransaction,
                onChanged: (v) => setState(() => _registerTransaction = v),
                contentPadding: EdgeInsets.zero,
                title: Text('Registrar en finanzas', style: text.titleSmall),
                subtitle: Text(
                  'Descuenta o suma el valor en la cuenta elegida',
                  style: text.bodySmall?.copyWith(fontSize: 11.5),
                ),
                activeThumbColor: colors.accent,
              ),
              AnimatedSize(
                duration: AppMotion.scale(context, AppMotion.standard),
                alignment: Alignment.topCenter,
                child: _registerTransaction
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.sm),
                          PickerField<int?>(
                            label: 'Cuenta',
                            value: _accountId,
                            options: [
                              for (final account in _accounts)
                                PickerOption<int?>(
                                  value: asIntOrNull(account['id']),
                                  label: asString(account['nombre']),
                                  subtitle: AccountType.parse(account['tipo'])
                                      .label,
                                  icon:
                                      AccountType.parse(account['tipo']).icon,
                                ),
                            ],
                            onChanged: (v) => setState(() => _accountId = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PickerField<String>(
                            label: 'Categoría',
                            value: _category,
                            searchable: true,
                            options: [
                              for (final c in _categories)
                                PickerOption(
                                  value: asString(c['valor']),
                                  label: asString(c['label']),
                                  icon: Icons.sell_rounded,
                                ),
                            ],
                            onChanged: (v) => setState(() => _category = v),
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            LoadingButton(
              label: isExpense ? 'Confirmar pago' : 'Confirmar recepción',
              icon: Icons.check_rounded,
              loading: _submitting,
              onPressed: _confirm,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.link_off_rounded,
              size: 48, color: AppColors.danger),
          const SizedBox(height: AppSpacing.lg),
          Text('Enlace no válido',
              textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Vista de éxito con confeti propio (CustomPainter, sin dependencias).
class _SuccessView extends StatefulWidget {
  const _SuccessView({super.key});

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Confeti detrás de la tarjeta.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(progress: _controller.value),
              ),
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.scale(context, AppMotion.dramatic),
                curve: AppMotion.overshoot,
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.success.withValues(alpha: 0.15),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 48, color: colors.success),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('¡Confirmado!',
                  textAlign: TextAlign.center, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gracias por confirmar. El compromiso quedó registrado.',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [
    Color(0xFF25D366), Color(0xFF4FC3F7), Color(0xFFFFD700),
    Color(0xFFFF7043), Color(0xFFBA68C8), Color(0xFFF06292),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final random = math.Random(7); // determinista: mismo confeti en cada frame

    for (var i = 0; i < 60; i++) {
      final startX = random.nextDouble() * size.width;
      final speed = 0.5 + random.nextDouble();
      final drift = (random.nextDouble() - 0.5) * 80;
      final y = size.height * progress * speed * 1.4 - 40;
      if (y < 0 || y > size.height) continue;

      final x = startX + math.sin(progress * 6 + i) * 14 + drift * progress;
      final rotation = progress * 8 + i.toDouble();
      final opacity = (1 - progress).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 7,
            height: 4 + random.nextDouble() * 5,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = _colors[i % _colors.length].withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
