import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const tokenKey = 'auth_token';
  static const steamIdKey = 'steam_id64';
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    final legacy = prefs.getString('steam_token');
    if (token == null && legacy != null) {
      await prefs.setString(tokenKey, legacy);
    }
    await prefs.remove('steam_token');
    return token ?? legacy;
  }

  Future<void> save(String token, String steamId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(steamIdKey, steamId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(steamIdKey);
    await prefs.remove('steam_token');
    await prefs.remove('user_info');
  }
}

class ApiClient {
  ApiClient({Dio? dio, SessionStore? store})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: defaultBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      store = store ?? SessionStore() {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (options.extra['public'] == true) {
              options.headers.remove('Authorization');
            } else {
              final token = await this.store.readToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onResponse: (response, handler) async {
          if (response.statusCode == 401) {
            await _handleUnauthorized(response.requestOptions);
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.next(response);
          }
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _handleUnauthorized(error.requestOptions);
          }
          handler.next(error);
        },
      ),
    );
  }

  static final instance = ApiClient();
  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/$'), '');
    }
    if (kReleaseMode) return 'http://localhost:8080/api/v1';
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return 'http://$host:8080/api/v1';
  }

  final Dio dio;
  final SessionStore store;
  final _expired = StreamController<void>.broadcast(sync: true);
  Stream<void> get sessionExpired => _expired.stream;

  Future<void> _handleUnauthorized(RequestOptions request) async {
    try {
      final current = await store.readToken();
      // Ignore failures belonging to an older account after an account switch.
      if (current == null ||
          request.headers['Authorization'] == 'Bearer $current') {
        await store.clear();
        _expired.add(null);
      }
    } catch (_) {
      _expired.add(null);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool public = false,
    bool withCredentials = false,
  }) async {
    final response = await dio.get<dynamic>(
      path,
      queryParameters: query,
      // The Web adapter forwards this to XMLHttpRequest.withCredentials.
      options: Options(
        extra: {'public': public, 'withCredentials': withCredentials},
      ),
    );
    final envelope = response.data;
    if (envelope is! Map || envelope['code'] != 0 || envelope['data'] is! Map) {
      throw const FormatException('API response does not match the contract');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);
