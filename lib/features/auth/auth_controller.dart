import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/callback_url.dart';
import '../../services/auth_service.dart';
import 'auth_state.dart';

/// Owns browser navigation, link subscriptions and the authentication lifecycle.
class AuthNotifier extends StateNotifier<AuthState>
    with WidgetsBindingObserver {
  AuthNotifier(
    this.service, {
    this.sessionTimeout = const Duration(seconds: 12),
    Stream<Uri>? links,
    this.initialLink,
  }) : _injectedLinks = links,
       super(const AuthState()) {
    _expiry = service.client.sessionExpired.listen((_) {
      _operation++;
      if (mounted) state = const AuthState();
    });
  }

  final AuthService service;
  final Duration sessionTimeout;
  final Stream<Uri>? _injectedLinks;
  final Future<Uri?> Function()? initialLink;
  StreamSubscription<Uri>? _links;
  StreamSubscription<Uri>? _webLinks;
  StreamSubscription<void>? _expiry;
  Future<void>? _initialization;
  Future<void>? _callback;
  Uri? _activeCallback;
  Uri? _completedCallback;
  int _operation = 0;
  int _logoutGeneration = 0;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final beforeLinks = _operation;
    Uri? initial;
    try {
      final appLinks = AppLinks();
      _links = (_injectedLinks ?? appLinks.uriLinkStream).listen(
        _onLink,
        onError: (_) {
          /* Restoration can continue without a link channel. */
        },
      );
      if (kIsWeb) _webLinks = browserAuthLinks().listen(_onLink);
      initial =
          await (initialLink?.call() ??
                  (kIsWeb ? Future.value(Uri.base) : appLinks.getInitialLink()))
              .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Missing platform channels must not keep the startup screen visible.
    }
    if (!mounted) return;
    if (_callback != null) {
      await _callback;
    } else if (initial != null &&
        AuthService.isAuthCallback(initial) &&
        initial.queryParameters.containsKey('token')) {
      await handleAuthCallback(initial);
    } else if (beforeLinks == _operation &&
        state.status != AuthStatus.authenticated) {
      await restoreSession();
    }
  }

  void _onLink(Uri uri) {
    if (mounted &&
        AuthService.isAuthCallback(uri) &&
        uri.queryParameters.containsKey('token')) {
      unawaited(handleAuthCallback(uri));
    }
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    if (!kIsWeb) return false;
    final uri = Uri.base.resolveUri(routeInformation.uri);
    if (!AuthService.isAuthCallback(uri)) return false;
    _onLink(uri);
    return true;
  }

  Future<void> loginWithSteam() async {
    if (!mounted || state.status == AuthStatus.authenticating) return;
    final operation = ++_operation;
    _completedCallback = null;
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final uri = await service.getLoginUrl().timeout(sessionTimeout);
      if (!mounted || operation != _operation) return;
      final opened =
          await (service.launcher?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                // Same-tab navigation survives web popup blockers after the API await.
                webOnlyWindowName: '_self',
              ));
      if (!opened) throw StateError('Cannot launch Steam');
      // Cancelling the external browser must leave a usable retry button.
      if (mounted && operation == _operation) state = const AuthState();
    } catch (_) {
      if (mounted && operation == _operation) {
        state = const AuthState(error: '无法打开 Steam 登录，请检查网络后重试');
      }
    }
  }

  Future<void> handleAuthCallback(Uri uri) async {
    if (!mounted || !AuthService.isAuthCallback(uri)) return;
    if (kIsWeb) clearAuthQuery();
    if (uri == _completedCallback) return;
    if (uri == _activeCallback) {
      await _callback;
      return;
    }
    // Serialize different callbacks so a previous token cannot overwrite a new one.
    final generation = _logoutGeneration;
    while (_callback != null) {
      await _callback;
    }
    if (generation != _logoutGeneration) return;
    if (!mounted || uri == _completedCallback) return;
    _activeCallback = uri;
    final work = _load(() => service.handleAuthCallback(uri));
    _callback = work;
    try {
      await work;
      if (mounted && state.status == AuthStatus.authenticated) {
        _completedCallback = uri;
      }
    } finally {
      _callback = null;
      _activeCallback = null;
    }
  }

  Future<void> restoreSession() => _load(service.restoreSession);

  Future<void> _load(Future<AuthSession?> Function() action) async {
    if (!mounted) return;
    final operation = ++_operation;
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final session = await action().timeout(sessionTimeout);
      if (!mounted || operation != _operation) return;
      state = session == null
          ? const AuthState()
          : AuthState(
              status: AuthStatus.authenticated,
              token: session.token,
              steamId: session.steamId,
            );
    } catch (error) {
      if (!mounted || operation != _operation) return;
      state = error is DioException && error.response?.statusCode == 401
          ? const AuthState()
          : AuthState(
              error: error is TimeoutException
                  ? '会话验证超时，请点击 Steam 登录或重试恢复会话'
                  : 'Steam 会话恢复失败，请检查网络后重试',
            );
    }
  }

  Future<void> logout() async {
    _logoutGeneration++;
    _operation++;
    await service.logout();
    if (mounted) state = const AuthState();
  }

  @override
  void dispose() {
    _operation++;
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    _webLinks?.cancel();
    _expiry?.cancel();
    super.dispose();
  }
}
