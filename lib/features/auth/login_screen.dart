import 'package:flutter/material.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  /// Cambia en cada fallo para disparar la sacudida de la tarjeta.
  int _errorTick = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).login(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;

      switch (result) {
        case AuthSuccess(:final user):
          AppFeedback.success();
          ref.read(authControllerProvider.notifier).adopt(user);
          context.go(Routes.selector);

        case AuthNeedsVerification(:final email, :final message):
          // La cuenta existe pero falta el código; el backend ya lo reenvió.
          AppFeedback.showInfo(
            context,
            message ?? 'Te enviamos un código a tu WhatsApp.',
          );
          context.go('${Routes.register}?verify=$email');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorTick++;
      });
      AppFeedback.error();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: OrbBackground(
        colors: [
          colors.accent.withValues(alpha: 0.22),
          const Color(0xFF3B82F6).withValues(alpha: 0.18),
          colors.accentLight.withValues(alpha: 0.14),
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
                      vertical: AppSpacing.xxxl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: BrandMark(size: 92, particles: true),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FadeSlideIn(
                            index: 0,
                            child: Text(
                              'Bienvenido de nuevo',
                              textAlign: TextAlign.center,
                              style: text.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FadeSlideIn(
                            index: 1,
                            child: Text(
                              'Inicia sesión para gestionar tu agenda y tus finanzas',
                              textAlign: TextAlign.center,
                              style: text.bodySmall,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),

                          _ErrorBanner(message: _error),

                          FadeSlideIn(
                            index: 2,
                            child: AppTextField(
                              label: 'Correo electrónico',
                              controller: _emailController,
                              hint: 'tucorreo@ejemplo.com',
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
                            index: 3,
                            child: AppTextField(
                              label: 'Contraseña',
                              controller: _passwordController,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Escribe tu contraseña'
                                  : null,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),
                          FadeSlideIn(
                            index: 4,
                            child: LoadingButton(
                              label: 'Iniciar sesión',
                              loading: _loading,
                              onPressed: _submit,
                              gradient: [colors.accent, const Color(0xFF2563EB)],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),
                          FadeSlideIn(
                            index: 5,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('¿No tienes cuenta?', style: text.bodySmall),
                                TextButton(
                                  onPressed: () => context.push(Routes.register),
                                  child: const Text('Crear cuenta gratis'),
                                ),
                              ],
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
      ),
    );
  }
}

/// Banner de error que aparece y desaparece sin dar tirones al layout.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: AppMotion.scale(context, AppMotion.standard),
      curve: AppMotion.emphasizedCurve,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        message!,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.danger,
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
