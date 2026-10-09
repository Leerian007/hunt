import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';

class AuthSession {
  const AuthSession(this.token, this.steamId);
  final String token;
  final String steamId;
}

class AuthService {
  AuthService({ApiClient? client, this.launcher})
    : client = client ?? ApiClient.instance;
  final ApiClient client;
  final Future<bool> Function(Uri)? launcher;

  Future<Uri> getLoginUrl([String? platform]) async {
    platform ??= kIsWeb ? 'web' : 'mobile';
    if (platform != 'web' && platform != 'mobile') {
      throw ArgumentError.value(platform, 'platform');
    }
    final data = await client.get(
      '/auth/steam/login-url',
      query: {'platform': platform},
      public: true,
      // Let the browser persist the HttpOnly state cookie before navigation.
      withCredentials: true,
    );
    final uri = Uri.parse((data['login_url'] ?? data['url']) as String);
    if (uri.scheme != 'https' ||
        uri.host != 'steamcommunity.com' ||
        uri.path != '/openid/login' ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid Steam login URL');
    }
    return uri;
  }

  static bool isAuthCallback(Uri uri) => kIsWeb
      ? (['http', 'https'].contains(uri.scheme) &&
            uri.origin == Uri.base.origin &&
            uri.path == '/auth/callback')
      : (uri.scheme == 'hunt1896' &&
            uri.host == 'auth' &&
            uri.path == '/steam');

  Future<AuthSession?> handleAuthCallback(Uri uri) async {
    if (!isAuthCallback(uri)) {
      throw const FormatException('Invalid callback URI');
    }
    final tokens = uri.queryParametersAll['token'];
    final ids = uri.queryParametersAll['steam_id'];
    if (tokens?.length != 1 ||
        ids?.length != 1 ||
        tokens!.single.isEmpty ||
        tokens.single.contains(RegExp(r'\s')) ||
        !RegExp(r'^\d{17}$').hasMatch(ids!.single)) {
      throw const FormatException('Invalid callback parameters');
    }
    await client.store.save(tokens.single, ids.single);
    // Do not trust query parameters as proof: validate the session and ID first.
    return restoreSession(expectedSteamId: ids.single);
  }

  Future<AuthSession?> restoreSession({String? expectedSteamId}) async {
    final token = await client.store.readToken();
    if (token == null || token.isEmpty) return null;
    final data = await verifySession();
    if (await client.store.readToken() != token) return null;
    final id = data['steam_id'];
    final expiry = DateTime.tryParse(data['expires_at']?.toString() ?? '');
    // The deployed backend uses authenticated; older API contracts used valid.
    final authenticated = data.containsKey('authenticated')
        ? data['authenticated']
        : data['valid'];
    if (authenticated != true ||
        id is! String ||
        !RegExp(r'^\d{17}$').hasMatch(id) ||
        expiry == null ||
        !expiry.isAfter(DateTime.now()) ||
        (expectedSteamId != null && id != expectedSteamId)) {
      await client.store.clear();
      return null;
    }
    if (await client.store.readToken() != token) return null;
    await client.store.save(token, id);
    return AuthSession(token, id);
  }

  Future<void> logout() => client.store.clear();

  Future<Map<String, dynamic>> verifySession() => client.get('/auth/session');
}
