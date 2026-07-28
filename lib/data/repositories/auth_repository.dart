import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_store.dart';
import '../models/user.dart';

/// Resultado de intentar entrar o registrarse.
sealed class AuthResult {
  const AuthResult();
}

/// Sesión iniciada: ya hay token guardado.
class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);
  final AppUser user;
}

/// La cuenta existe pero falta confirmar el código que llegó por WhatsApp.
class AuthNeedsVerification extends AuthResult {
  const AuthNeedsVerification({required this.email, this.whatsapp, this.message});
  final String email;
  final String? whatsapp;
  final String? message;
}

class AuthRepository {
  AuthRepository(this._api, this._tokenStore);

  final ApiClient _api;
  final TokenStore _tokenStore;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _api.post(
        '/api/login',
        body: {'email': email.trim(), 'password': password},
        authenticated: false,
      );
      return _handleAuthPayload(data, fallbackEmail: email);
    } on ApiException catch (e) {
      // El backend responde 403 con `verification_required` cuando la cuenta
      // existe pero no está verificada, y de paso reenvía el código.
      if (e.isForbidden && e.data?['verification_required'] == true) {
        return AuthNeedsVerification(
          email: e.data?['email']?.toString() ?? email,
          whatsapp: e.data?['whatsapp']?.toString(),
          message: e.message,
        );
      }
      rethrow;
    }
  }

  Future<AuthResult> register({
    required String nombre,
    required String email,
    required String password,
    required String whatsapp,
  }) async {
    final data = await _api.post(
      '/api/register',
      body: {
        'nombre': nombre.trim(),
        'email': email.trim(),
        'password': password,
        'whatsapp': whatsapp.replaceAll(RegExp(r'\D'), ''),
      },
      authenticated: false,
    );
    return _handleAuthPayload(data, fallbackEmail: email);
  }

  /// Confirma el código de 6 dígitos recibido por WhatsApp.
  Future<AuthResult> verifyCode({
    required String email,
    required String code,
  }) async {
    final data = await _api.post(
      '/api/register/verify',
      body: {'email': email.trim(), 'code': code.trim()},
      authenticated: false,
    );
    return _handleAuthPayload(data, fallbackEmail: email);
  }

  Future<void> resendCode(String email) async {
    await _api.post(
      '/api/register/resend-code',
      body: {'email': email.trim()},
      authenticated: false,
    );
  }

  Future<AuthResult> _handleAuthPayload(
    dynamic data, {
    required String fallbackEmail,
  }) async {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    if (map['verification_required'] == true) {
      return AuthNeedsVerification(
        email: map['email']?.toString() ?? fallbackEmail,
        whatsapp: map['whatsapp']?.toString(),
        message: map['message']?.toString(),
      );
    }

    final token = map['token']?.toString();
    final userMap = map['user'];
    if (token == null || token.isEmpty || userMap is! Map) {
      throw const ApiException('El servidor no devolvió una sesión válida.');
    }

    final user = AppUser.fromJson(Map<String, dynamic>.from(userMap));
    await _tokenStore.saveSession(token: token, user: user.toJson());
    return AuthSuccess(user);
  }

  /// Usuario guardado de la sesión anterior, si la hay.
  AppUser? currentUser() {
    final raw = _tokenStore.readUser();
    return raw == null ? null : AppUser.fromJson(raw);
  }

  Future<bool> hasSession() => _tokenStore.hasSession();

  Future<void> logout() => _tokenStore.clear();
}
