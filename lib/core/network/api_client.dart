import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';
import 'api_exception.dart';

/// Cliente HTTP contra el backend Fastify existente.
///
/// El mismo servidor que usa la web (`/api/...`, JWT en `Authorization`), sin
/// ningún cambio del lado del servidor.
class ApiClient {
  ApiClient({required TokenStore tokenStore, String? baseUrl})
      : _tokenStore = tokenStore,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? defaultBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
            // Dejamos pasar los códigos de error para traducirlos nosotros
            // en ApiException con el mensaje que manda el backend.
            validateStatus: (status) => status != null && status < 500,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.extra.containsKey(_skipAuthKey)) {
            final token = await _tokenStore.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final code = response.statusCode ?? 0;
          if (code >= 400) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
              true,
            );
            return;
          }
          handler.next(response);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false),
      );
    }
  }

  /// URL del backend en producción, la misma que usa `.env.production`.
  static const String defaultBaseUrl = 'https://dibeltran05.alwaysdata.net';

  static const String _skipAuthKey = 'skipAuth';

  /// Marca una petición como pública (sin cabecera Authorization).
  static final Options publicOptions = Options(extra: {_skipAuthKey: true});

  final Dio _dio;
  final TokenStore _tokenStore;

  /// Se dispara cuando el backend responde 401: la sesión ya no vale.
  final ValueNotifier<int> unauthorizedSignal = ValueNotifier(0);

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) {
    return _send(
      () => _dio.get(
        path,
        queryParameters: query,
        options: authenticated ? null : publicOptions,
      ),
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) {
    return _send(
      () => _dio.post(
        path,
        data: body,
        queryParameters: query,
        options: authenticated ? null : publicOptions,
      ),
    );
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _send(() => _dio.put(path, data: body));
  }

  Future<dynamic> delete(String path, {Object? body}) {
    return _send(() => _dio.delete(path, data: body));
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } catch (error) {
      final failure = ApiException.from(error);
      if (failure.isUnauthorized) {
        unauthorizedSignal.value++;
      }
      throw failure;
    }
  }

  /// Lista de mapas, que es lo que devuelven casi todos los endpoints CRUD.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final data = await get(path, query: query, authenticated: authenticated);
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Mapa único.
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final data = await get(path, query: query, authenticated: authenticated);
    if (data is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(data);
  }

  void dispose() {
    unauthorizedSignal.dispose();
    _dio.close(force: true);
  }
}
