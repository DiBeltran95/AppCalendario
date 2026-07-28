import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/confirm/confirm_screen.dart';
import '../features/module_selector/module_selector_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/splash/splash_screen.dart';
import 'theme/app_motion.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const selector = '/select';
  static const home = '/home';
  static const settings = '/settings';

  /// Ruta pública que abre un enlace de confirmación de evento.
  static const confirm = '/confirmar/:uuid';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Un ValueNotifier hace de puente entre Riverpod y el `refreshListenable`
  // de go_router, para que la redirección se reevalúe al cambiar la sesión.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: Routes.register,
        pageBuilder: (context, state) => _sharedAxis(
          state,
          // `?verify=correo` entra directo al paso del código: es la ruta que
          // usa el login cuando la cuenta existe pero no está confirmada.
          RegisterScreen(verifyEmail: state.uri.queryParameters['verify']),
        ),
      ),
      GoRoute(
        path: Routes.selector,
        pageBuilder: (context, state) => _fade(state, const ModuleSelectorScreen()),
      ),
      GoRoute(
        path: Routes.home,
        pageBuilder: (context, state) => _fade(state, const HomeShell()),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (context, state) => _sharedAxis(state, const SettingsScreen()),
      ),
      GoRoute(
        path: Routes.confirm,
        pageBuilder: (context, state) => _fade(
          state,
          ConfirmScreen(uuid: state.pathParameters['uuid'] ?? ''),
        ),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // La confirmación de eventos es pública: llega por enlace y no exige sesión.
      if (location.startsWith('/confirmar/')) return null;

      // Mientras se lee el almacenamiento seguro nos quedamos en el splash.
      if (auth is AuthUnknown) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final signedIn = auth is AuthSignedIn;
      final isAuthRoute = location == Routes.login || location == Routes.register;

      if (!signedIn) {
        return isAuthRoute ? null : Routes.login;
      }

      // Con sesión abierta, el splash y las pantallas de acceso sobran.
      if (isAuthRoute || location == Routes.splash) return Routes.selector;

      return null;
    },
  );
});

/// Transición entre pantallas del mismo nivel.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: AppMotion.emphasized,
    reverseTransitionDuration: AppMotion.standard,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasizedCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.985, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Transición cuando se baja un nivel en la jerarquía.
CustomTransitionPage<void> _sharedAxis(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: AppMotion.emphasized,
    reverseTransitionDuration: AppMotion.standard,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasizedCurve,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
