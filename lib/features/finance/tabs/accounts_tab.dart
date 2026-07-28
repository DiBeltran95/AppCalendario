import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/finance.dart';
import '../../../shared/animations/entrance.dart';
import '../../../shared/widgets/animated_counter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/panel_parts.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../shell/dashboard_controller.dart';
import '../account_sheet.dart';
import '../finance_sheets.dart';

/// Pestaña Cuentas: tarjetas físicas con flip 3D, CDT con rendimiento en vivo
/// y transferencias.
class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final accounts = state.bootstrap.cuentas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PanelActionButton(
                label: 'Agregar cuenta',
                icon: Icons.add_card_rounded,
                color: AppColors.gold,
                onPressed: () => showAccountSheet(context),
              ),
            ),
            if (accounts.length >= 2) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PanelActionButton(
                  label: 'Transferir',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.sky,
                  onPressed: () => showTransferSheet(context),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        if (accounts.isEmpty)
          EmptyState(
            icon: Icons.credit_card_rounded,
            title: 'Sin cuentas registradas',
            message:
                'Registra tus cuentas, tarjetas y CDT para llevar el pulso de tu dinero.',
            color: AppColors.gold,
            actionLabel: 'Crear cuenta',
            onAction: () => showAccountSheet(context),
            compact: true,
          )
        else
          for (var i = 0; i < accounts.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: accounts[i].isCreditCard
                    ? _CreditCardTile(account: accounts[i], state: state)
                    : _AccountTile(account: accounts[i], state: state),
              ),
            ),
      ],
    );
  }
}

/// Tarjeta de crédito con volteo 3D: el frente muestra la marca y la deuda,
/// el reverso el detalle de cupo y corte.
class _CreditCardTile extends StatefulWidget {
  const _CreditCardTile({required this.account, required this.state});

  final Account account;
  final DashboardState state;

  @override
  State<_CreditCardTile> createState() => _CreditCardTileState();
}

class _CreditCardTileState extends State<_CreditCardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.dramatic,
  );

  bool get _showingBack => _controller.value >= 0.5;

  void _flip() {
    if (_controller.isAnimating) return;
    _showingBack ? _controller.reverse() : _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      onLongPress: () => showAccountSheet(context, account: widget.account),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          final angle = t * math.pi;
          final isBack = angle > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011) // perspectiva
              ..rotateY(angle),
            child: isBack
                ? Transform(
                    // El reverso se pre-espeja para que su texto se lea bien.
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardBack(account: widget.account),
                  )
                : _CardFront(account: widget.account),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _CardShell(
      gradient: const [Color(0xFF7A1F2B), Color(0xFF3D0E14)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chip de la tarjeta.
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8C878), Color(0xFFB8944A)],
                  ),
                ),
              ),
              Icon(
                Icons.contactless_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 22,
              ),
            ],
          ),
          Text(
            account.nombre,
            style: text.titleMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEUDA ACTUAL',
                    style: text.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                  AnimatedCounter(
                    value: account.saldo,
                    style: text.headlineSmall?.copyWith(
                      color: const Color(0xFFFF8A80),
                    ),
                  ),
                ],
              ),
              Text(
                'Toca para voltear',
                style: text.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final available = math.max(0, account.limite - account.saldo);

    return _CardShell(
      gradient: const [Color(0xFF3D0E14), Color(0xFF24080C)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banda magnética.
          Container(
            height: 26,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            color: Colors.black.withValues(alpha: 0.55),
          ),
          _BackRow(label: 'Cupo autorizado', value: AppCurrency.format(account.limite)),
          _BackRow(
            label: 'Disponible',
            value: AppCurrency.format(available.toDouble()),
            valueColor: AppColors.income,
          ),
          _BackRow(
            label: 'Uso del cupo',
            value: '${account.creditUsage.toStringAsFixed(1)}%',
            valueColor: account.creditUsage > 50
                ? AppColors.danger
                : account.creditUsage > 30
                    ? AppColors.warning
                    : AppColors.income,
          ),
          if (account.diaCorte != null)
            _BackRow(
              label: 'Día de corte',
              value: 'Día ${account.diaCorte} de cada mes',
              valueColor: AppColors.gold,
            ),
          const Spacer(),
          Center(
            child: Text(
              'Mantén pulsado para editar',
              style: text.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
            ),
          ),
          Text(
            value,
            style: text.bodySmall?.copyWith(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.gradient});

  final Widget child;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.62,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Cuenta corriente / ahorros / efectivo / CDT.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.state});

  final Account account;
  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final account_ = account;
    final selectedDay = state.selectedDay;
    final isFutureProjection = account_.isCdt &&
        selectedDay != null &&
        selectedDay.compareTo(AppDate.today()) > 0;

    return Material(
      color: colors.bgTertiary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: () => showAccountSheet(context, account: account_),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(account_.tipo.icon, size: 20, color: account_.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(account_.nombre, style: text.titleSmall),
                  ),
                  StatusPill(
                    label: account_.tipo.label.toUpperCase(),
                    color: account_.color,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isFutureProjection ? 'SALDO PROYECTADO' : 'SALDO DISPONIBLE',
                    style: text.labelSmall?.copyWith(fontSize: 9.5),
                  ),
                  AnimatedCounter(
                    value: isFutureProjection
                        ? account_.projectedBalanceAt(selectedDay)
                        : account_.saldo,
                    style: text.headlineSmall?.copyWith(
                      color: account_.saldo >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),

              if (account_.isCdt) ...[
                const SizedBox(height: AppSpacing.md),
                Divider(color: colors.divider, height: 1),
                const SizedBox(height: AppSpacing.md),
                _CdtMetrics(account: account_),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Métricas del CDT, con el rendimiento diario subiendo en tiempo real.
class _CdtMetrics extends StatefulWidget {
  const _CdtMetrics({required this.account});

  final Account account;

  @override
  State<_CdtMetrics> createState() => _CdtMetricsState();
}

class _CdtMetricsState extends State<_CdtMetrics> {
  Timer? _timer;

  /// Interés ganado desde que la tarjeta está en pantalla: el rendimiento
  /// diario prorrateado por segundo. Un detalle deleitoso y casi gratis.
  double _liveYield = 0;

  @override
  void initState() {
    super.initState();
    final perSecond = widget.account.dailyYield / 86400;
    if (perSecond > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _liveYield += perSecond);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final account = widget.account;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Tasa pactada',
                value: '${account.interesTasa}% E.A.',
                color: AppColors.goldDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Metric(
                label: 'Rinde hoy',
                value: '+${AppCurrency.format(account.dailyYield)}',
                color: AppColors.income,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (account.hasMaturity)
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Retorno estimado',
                  value: '+${AppCurrency.format(account.totalYield)}',
                  color: AppColors.sky,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  label: 'Restante',
                  value: '${account.daysRemaining}d de ${account.plazoDias}d',
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          )
        else
          _Metric(
            label: 'Modalidad',
            value: 'Rendimiento continuo (cajita)',
            color: AppColors.sky,
          ),

        if (account.hasMaturity) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vence: ${account.maturityDate == null ? '—' : AppDate.long(account.maturityDate!)}',
                      style: text.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ProgressBar(
                      progress: account.maturityProgress / 100,
                      color: AppColors.gold,
                      height: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ProgressRing(
                progress: account.maturityProgress / 100,
                size: 40,
                strokeWidth: 4,
                color: AppColors.gold,
                child: Text(
                  '${account.maturityProgress.toStringAsFixed(0)}%',
                  style: text.labelSmall?.copyWith(fontSize: 8.5),
                ),
              ),
            ],
          ),
        ],

        if (_liveYield > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 13, color: AppColors.income),
              Text(
                'Ganado mientras miras: +${_liveYield.toStringAsFixed(2)}',
                style: text.labelSmall?.copyWith(
                  color: AppColors.income,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelSmall?.copyWith(fontSize: 8.5, letterSpacing: 0.6),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: text.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
