import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/orb_background.dart';
import '../auth/auth_controller.dart';
import '../auth/brand_mark.dart';

/// Selector de espacio de trabajo: Personal (activo) o Empresa (próximamente).
class ModuleSelectorScreen extends ConsumerStatefulWidget {
  const ModuleSelectorScreen({super.key});

  @override
  ConsumerState<ModuleSelectorScreen> createState() =>
      _ModuleSelectorScreenState();
}

class _ModuleSelectorScreenState extends ConsumerState<ModuleSelectorScreen> {
  bool _empresaTapped = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: OrbBackground(
        showDotGrid: true,
        colors: [
          const Color(0xFF06B6D4).withValues(alpha: 0.18),
          const Color(0xFF6366F1).withValues(alpha: 0.18),
          const Color(0xFFA855F7).withValues(alpha: 0.15),
        ],
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await AppFeedback.confirm(
                        context,
                        title: 'Cerrar sesión',
                        message: '¿Seguro que quieres salir de tu cuenta?',
                        confirmLabel: 'Salir',
                        destructive: false,
                      );
                      if (ok) {
                        await ref.read(authControllerProvider.notifier).signOut();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Salir'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const BrandMark(size: 76),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          index: 0,
                          child: Text(
                            'BIENVENIDO DE VUELTA',
                            style: text.labelSmall?.copyWith(
                              color: const Color(0xFF22D3EE),
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FadeSlideIn(
                          index: 1,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: text.displaySmall,
                              children: [
                                const TextSpan(text: 'Hola, '),
                                TextSpan(
                                  text: user?.firstName ?? 'Usuario',
                                  style: const TextStyle(
                                    foreground: null,
                                    color: Color(0xFF22D3EE),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeSlideIn(
                          index: 2,
                          child: Text(
                            '¿Cómo deseas continuar hoy?',
                            style: text.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        FadeSlideIn(
                          index: 3,
                          child: _SpaceCard(
                            title: 'Personal',
                            description:
                                'Tu espacio personal: calendario, finanzas, ciclo, hábitos y notas.',
                            icon: Icons.person_outline_rounded,
                            accent: const Color(0xFF06B6D4),
                            tags: const [
                              'Finanzas',
                              'Calendario',
                              'Ciclo',
                              'Hábitos',
                              'Notas',
                            ],
                            ctaLabel: 'Ingresar',
                            onTap: () {
                              AppFeedback.light();
                              context.go(Routes.home);
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FadeSlideIn(
                          index: 4,
                          child: _SpaceCard(
                            title: 'Empresa',
                            description:
                                'Gestión empresarial, equipos, facturación y reportes avanzados.',
                            icon: Icons.business_center_outlined,
                            accent: const Color(0xFF6366F1),
                            tags: const [
                              'Equipos',
                              'Reportes',
                              'Facturación',
                              'Analytics',
                            ],
                            badge: 'PRÓXIMAMENTE',
                            ctaLabel: _empresaTapped
                                ? 'Estamos trabajando en este módulo…'
                                : 'Disponible pronto',
                            ctaIcon: Icons.schedule_rounded,
                            dimmed: true,
                            onTap: () {
                              AppFeedback.select();
                              setState(() => _empresaTapped = true);
                              Future.delayed(const Duration(seconds: 3), () {
                                if (mounted) {
                                  setState(() => _empresaTapped = false);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de espacio con inclinación 3D que sigue al dedo.
class _SpaceCard extends StatefulWidget {
  const _SpaceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.tags,
    required this.ctaLabel,
    required this.onTap,
    this.badge,
    this.ctaIcon,
    this.dimmed = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final List<String> tags;
  final String ctaLabel;
  final VoidCallback onTap;
  final String? badge;
  final IconData? ctaIcon;
  final bool dimmed;

  @override
  State<_SpaceCard> createState() => _SpaceCardState();
}

class _SpaceCardState extends State<_SpaceCard> {
  Offset _tilt = Offset.zero;
  bool _pressed = false;

  /// Convierte la posición del dedo dentro de la tarjeta en una inclinación
  /// normalizada de -1 a 1 en cada eje.
  void _updateTilt(Offset local, Size size) {
    setState(() {
      _tilt = Offset(
        ((local.dx / size.width) - 0.5) * 2,
        ((local.dy / size.height) - 0.5) * 2,
      );
    });
  }

  void _reset() => setState(() {
        _tilt = Offset.zero;
        _pressed = false;
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const maxTilt = 0.06; // radianes: suficiente para notarse, no para marear

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 260);

        return GestureDetector(
          onTapDown: (d) {
            setState(() => _pressed = true);
            _updateTilt(d.localPosition, size);
          },
          onTapUp: (_) {
            _reset();
            widget.onTap();
          },
          onTapCancel: _reset,
          onPanUpdate: (d) => _updateTilt(d.localPosition, size),
          onPanEnd: (_) => _reset(),
          child: AnimatedContainer(
            duration: AppMotion.scale(context, AppMotion.quick),
            curve: AppMotion.enter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // perspectiva
              ..rotateX(-_tilt.dy * maxTilt)
              ..rotateY(_tilt.dx * maxTilt)
              ..scaleByDouble(_pressed ? 0.98 : 1.0, _pressed ? 0.98 : 1.0, 1, 1),
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sheet),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: _pressed
                    ? widget.accent.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accent.withValues(alpha: _pressed ? 0.14 : 0.06),
                  Colors.transparent,
                ],
              ),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.25),
                        blurRadius: 50,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.scale(context, AppMotion.standard),
                      curve: AppMotion.overshoot,
                      width: 68,
                      height: 68,
                      transform: Matrix4.identity()
                        ..rotateZ(_pressed ? -0.07 : 0),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.accent
                            .withValues(alpha: _pressed ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(widget.icon, size: 34, color: widget.accent),
                    ),
                    const Spacer(),
                    if (widget.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          widget.badge!,
                          style: text.labelSmall?.copyWith(
                            color: widget.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(widget.title, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.description, style: text.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tag in widget.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: text.labelSmall?.copyWith(
                            color: widget.accent.withValues(alpha: 0.9),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AnimatedSwitcher(
                  duration: AppMotion.scale(context, AppMotion.standard),
                  child: Row(
                    key: ValueKey(widget.ctaLabel),
                    children: [
                      Text(
                        widget.ctaLabel,
                        style: text.labelLarge?.copyWith(
                          color: widget.dimmed
                              ? widget.accent.withValues(alpha: 0.7)
                              : widget.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AnimatedSlide(
                        duration: AppMotion.scale(context, AppMotion.standard),
                        offset: Offset(_pressed ? 0.4 : 0, 0),
                        child: Transform.rotate(
                          angle: widget.ctaIcon == null ? 0 : 0,
                          child: Icon(
                            widget.ctaIcon ?? Icons.arrow_forward_rounded,
                            size: 18,
                            color: widget.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.dimmed) ...[
                  const SizedBox(height: AppSpacing.lg),
                  // Línea inferior que se enciende al presionar.
                  AnimatedOpacity(
                    duration: AppMotion.scale(context, AppMotion.standard),
                    opacity: _pressed ? 1 : 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            widget.accent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ángulo máximo de inclinación, expuesto por si se quiere calibrar.
const double kMaxTiltRadians = math.pi / 40;
