import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/panel_parts.dart';
import '../auth/auth_controller.dart';

/// Ajustes: perfil, caché y cierre de sesión.
///
/// Pantalla que la versión web no tenía; concentra lo que allí estaba
/// disperso (o directamente no existía).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Perfil.
          FadeSlideIn(
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colors.accent, colors.accentDark],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        user?.initials ?? '?',
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nombre ?? 'Usuario', style: text.titleMedium),
                        Text(user?.email ?? '', style: text.bodySmall),
                        if (user?.whatsapp != null)
                          Row(
                            children: [
                              const Icon(Icons.chat_rounded,
                                  size: 12, color: Color(0xFF25D366)),
                              const SizedBox(width: 4),
                              Text(user!.whatsapp!, style: text.bodySmall),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const FadeSlideIn(
            index: 1,
            child: SectionTitle(title: 'Datos', icon: Icons.storage_rounded),
          ),
          FadeSlideIn(
            index: 2,
            child: _SettingsTile(
              icon: Icons.cleaning_services_rounded,
              title: 'Limpiar caché local',
              subtitle:
                  'Borra los datos guardados en el teléfono. La próxima carga vendrá completa del servidor.',
              onTap: () async {
                await ref.read(cacheStoreProvider).clear();
                if (context.mounted) {
                  AppFeedback.showSuccess(context, 'Caché limpiada');
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const FadeSlideIn(
            index: 3,
            child: SectionTitle(
              title: 'Acerca de',
              icon: Icons.info_outline_rounded,
            ),
          ),
          FadeSlideIn(
            index: 4,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agendaservi', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Calendario, finanzas, ciclo, notas y hábitos.\n'
                    'Versión 1.0.0',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          FadeSlideIn(
            index: 5,
            child: _SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Cerrar sesión',
              subtitle: 'Salir de tu cuenta en este dispositivo.',
              color: AppColors.danger,
              onTap: () async {
                final ok = await AppFeedback.confirm(
                  context,
                  title: 'Cerrar sesión',
                  message: '¿Seguro que quieres salir?',
                  confirmLabel: 'Salir',
                  destructive: false,
                );
                if (ok) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final accent = color ?? colors.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  Text(subtitle,
                      style: text.bodySmall?.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
