import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

/// Estado de la sesión.
sealed class AuthState {
  const AuthState();
}

/// Aún no sabemos si hay sesión (se está leyendo el almacenamiento seguro).
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AppUser user;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // El 401 del interceptor cierra la sesión sin que ninguna pantalla tenga
    // que ocuparse de ello.
    final api = ref.watch(apiClientProvider);
    void onUnauthorized() {
      if (state is AuthSignedIn) signOut();
    }

    api.unauthorizedSignal.addListener(onUnauthorized);
    ref.onDispose(() => api.unauthorizedSignal.removeListener(onUnauthorized));

    _restore();
    return const AuthUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final hasSession = await _repo.hasSession();
    final user = _repo.currentUser();
    state = (hasSession && user != null) ? AuthSignedIn(user) : const AuthSignedOut();
  }

  /// Registra la sesión tras un login/registro/verificación correctos.
  void adopt(AppUser user) => state = AuthSignedIn(user);

  Future<void> signOut() async {
    await _repo.logout();
    await ref.read(cacheStoreProvider).clear();
    state = const AuthSignedOut();
  }

  AppUser? get user => switch (state) {
        AuthSignedIn(:final user) => user,
        _ => null,
      };
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Usuario actual, o null si no hay sesión.
final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.user : null;
});

/// El buscador corporativo solo está habilitado en el backend para ciertos
/// usuarios; replicamos la misma condición para no mostrar una función que
/// respondería 403.
final canUseCorporateSearchProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return user.id == 1 || user.email == 'di.beltran@udla.edu.co';
});
