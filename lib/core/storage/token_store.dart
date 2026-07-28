import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el JWT y el usuario de la sesión.
///
/// El token va en almacenamiento cifrado (Keystore en Android); el perfil, que
/// no es sensible, en preferencias normales para poder leerlo sin await del
/// canal seguro en el arranque.
class TokenStore {
  TokenStore(this._prefs);

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedToken;

  Future<String?> readToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _secure.read(key: _tokenKey);
    } catch (_) {
      // Si el Keystore falla (pasa en algunos equipos tras restaurar backup),
      // preferimos una sesión perdida a una app que no arranca.
      _cachedToken = null;
    }
    return _cachedToken;
  }

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    _cachedToken = token;
    await _secure.write(key: _tokenKey, value: token);
    await _prefs.setString(_userKey, jsonEncode(user));
  }

  Map<String, dynamic>? readUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _cachedToken = null;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {}
    await _prefs.remove(_userKey);
  }

  Future<bool> hasSession() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }
}
