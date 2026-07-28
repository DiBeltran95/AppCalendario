import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/shell/dashboard_controller.dart';
import 'router.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';

class AgendaserviApp extends ConsumerWidget {
  const AgendaserviApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final module = ref.watch(activeModuleProvider);

    return MaterialApp.router(
      title: 'Agendaservi',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      // Todo el texto de la app está en español de Colombia.
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: AppTheme.forModule(module),

      // Aquí está el corazón del cambio de módulo: en vez de sustituir el tema
      // de golpe, AnimatedTheme interpola cada color (ver AppColors.lerp), así
      // que pasar de Finanzas a Ciclo tiñe la pantalla de forma continua.
      builder: (context, child) => AnimatedTheme(
        data: AppTheme.forModule(module),
        duration: AppMotion.scale(context, AppMotion.emphasized),
        curve: AppMotion.emphasizedCurve,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
