import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/loading_button.dart';
import '../../shared/widgets/orb_background.dart';
import 'auth_controller.dart';
import 'brand_mark.dart';
import 'countdown_ring.dart';
import 'otp_field.dart';

/// Registro en dos pasos: datos y verificación por WhatsApp.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.verifyEmail});

  /// Si llega, se entra directo al paso de verificación (viene del login
  /// cuando la cuenta existe pero no está confirmada).
  final String? verifyEmail;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<OtpFieldState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _whatsappController = TextEditingController();

  bool _verifying = false;
  bool _loading = false;
  String? _error;
  int _errorTick = 0;

  /// Segundos que faltan para poder reenviar el código.
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    if (widget.verifyEmail != null && widget.verifyEmail!.isNotEmpty) {
      _emailController.text = widget.verifyEmail!;
      _verifying = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _fail(String message) {
    setState(() {
      _error = message;
      _errorTick++;
    });
    AppFeedback.error();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).register(
            nombre: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            whatsapp: _whatsappController.text,
          );
      if (!mounted) return;

      switch (result) {
        case AuthSuccess(:final user):
          ref.read(authControllerProvider.notifier).adopt(user);
          context.go(Routes.selector);
        case AuthNeedsVerification():
          setState(() {
            _verifying = true;
            _canResend = false;
          });
          AppFeedback.light();
      }
    } on ApiException catch (e) {
      if (mounted) _fail(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).verifyCode(
            email: _emailController.text,
            code: code,
          );
      if (!mounted) return;

      if (result case AuthSuccess(:final user)) {
        AppFeedback.success();
        ref.read(authControllerProvider.notifier).adopt(user);
        context.go(Routes.selector);
      } else {
        _fail('El código no es válido. Revísalo e inténtalo de nuevo.');
        _otpKey.currentState?.clear();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _fail(e.message);
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _canResend = false);
    try {
      await ref.read(authRepositoryProvider).resendCode(_emailController.text);
      if (mounted) {
        AppFeedback.showInfo(context, 'Te enviamos un código nuevo.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _fail(e.message);
        setState(() => _canResend = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: OrbBackground(
        colors: [
          colors.accent.withValues(alpha: 0.2),
          const Color(0xFF6366F1).withValues(alpha: 0.16),
          colors.accentLight.withValues(alpha: 0.12),
        ],
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Shake(
                  trigger: _errorTick == 0 ? null : _errorTick,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StepIndicator(step: _verifying ? 1 : 0),
                        const SizedBox(height: AppSpacing.xxl),

                        // El paso 1 y el paso 2 se cruzan en horizontal, que es
                        // como Material comunica "avanzas dentro del mismo flujo".
                        AnimatedSize(
                          duration: AppMotion.scale(context, AppMotion.emphasized),
                          curve: AppMotion.emphasizedCurve,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration:
                                AppMotion.scale(context, AppMotion.emphasized),
                            switchInCurve: AppMotion.emphasizedCurve,
                            switchOutCurve: AppMotion.exit,
                            transitionBuilder: (child, animation) {
                              final incoming =
                                  child.key == ValueKey(_verifying);
                              final begin = Offset(incoming ? 0.25 : -0.25, 0);
                              return SlideTransition(
                                position: Tween(begin: begin, end: Offset.zero)
                                    .animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: _verifying
                                ? _buildVerifyStep(context)
                                : _buildFormStep(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey(false),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 72)),
          const SizedBox(height: AppSpacing.md),
          Text('Crea tu cuenta',
              textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Te enviaremos un código por WhatsApp para confirmar que eres tú',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxl),

          _InlineError(message: _error),

          FadeSlideIn(
            index: 0,
            child: AppTextField(
              label: 'Nombre completo',
              controller: _nameController,
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Escribe tu nombre'
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 1,
            child: AppTextField(
              label: 'Correo electrónico',
              controller: _emailController,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Escribe tu correo';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Ese correo no parece válido';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 2,
            child: AppTextField(
              label: 'WhatsApp',
              controller: _whatsappController,
              icon: Icons.chat_rounded,
              hint: '57 300 000 0000',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              helperText: 'Incluye el código de país. Aquí llegará tu código.',
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) {
                  return 'Debe tener al menos 10 dígitos con el código de país';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 3,
            child: AppTextField(
              label: 'Contraseña',
              controller: _passwordController,
              icon: Icons.lock_outline_rounded,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Usa al menos 6 caracteres'
                  : null,
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          LoadingButton(
            label: 'Crear cuenta',
            loading: _loading,
            onPressed: _register,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.login),
            child: const Text('Ya tengo cuenta'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyStep(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey(true),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.sms_rounded, size: 32, color: colors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Confirma tu WhatsApp',
            textAlign: TextAlign.center, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Escribe el código de 6 dígitos que enviamos a tu WhatsApp',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xxl),

        _InlineError(message: _error),

        SizedBox(
          height: 62,
          child: OtpField(
            key: _otpKey,
            enabled: !_loading,
            errorTrigger: _errorTick == 0 ? null : _errorTick,
            onCompleted: _verify,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        if (_loading)
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: colors.accent,
              ),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_canResend)
                TextButton.icon(
                  onPressed: _resend,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reenviar código'),
                )
              else ...[
                Text('Podrás reenviarlo en', style: text.bodySmall),
                const SizedBox(width: AppSpacing.md),
                CountdownRing(
                  seconds: 60,
                  onFinished: () {
                    if (mounted) setState(() => _canResend = true);
                  },
                ),
              ],
            ],
          ),

        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _verifying = false;
                    _error = null;
                  }),
          child: const Text('Usar otros datos'),
        ),
      ],
    );
  }
}

/// Barra de progreso de dos pasos.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.scale(context, AppMotion.emphasized),
              curve: AppMotion.emphasizedCurve,
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? colors.accent : colors.bgHover,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Error en línea, compartido por ambos pasos.
class _InlineError extends StatelessWidget {
  const _InlineError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.scale(context, AppMotion.standard),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        message!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
