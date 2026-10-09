import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunt/core/network/api_client.dart';
import 'package:hunt/features/auth/auth_provider.dart';
import 'package:hunt/services/auth_service.dart';

import 'package:hunt/services/player_service.dart';

import 'package:hunt/main.dart';

const steamId = '76561198012345678';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late List<RequestOptions> requests;
  var unauthorized = false;
  var valid = true;
  var sessionFlag = 'valid';
  var loginUrlField = 'login_url';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    unauthorized = false;
    valid = true;
    sessionFlag = 'valid';
    loginUrlField = 'login_url';
    client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://localhost:8080/api/v1')),
    );
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (unauthorized) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 401,
                ),
              ),
              true,
            );
            return;
          }
          final data = switch (options.path) {
            '/auth/steam/login-url' => {
              loginUrlField: 'https://steamcommunity.com/openid/login?openid.mode=checkid_setup',
            },
            '/auth/session' => {
              sessionFlag: valid,
              'steam_id': steamId,
              'expires_at': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            },
            '/players/$steamId/stats' => {
              'total_kills': 4,
              'extracted_matches': 2,
              'total_bounty_extracted': 500,
              'mmr_stars': 3,
            },
            '/players/$steamId/matches' => {'list': [], 'total': 0, 'pages': 0},
            '/players/$steamId/summary' => {
              'steam_id': steamId,
              'persona_name': 'Real Hunter',
              'avatar_full': 'https://avatars.steamstatic.com/example_full.jpg',
            },
            _ => throw StateError('Unexpected request'),
          };
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'code': 0, 'data': data},
            ),
          );
        },
      ),
    );
  });

  test('mobile login uses contract and launches Steam', () async {
    Uri? launched;
    final notifier = AuthNotifier(
      AuthService(
        client: client,
        launcher: (uri) async {
          launched = uri;
          return true;
        },
      ),
    );
    addTearDown(notifier.dispose);
    await notifier.loginWithSteam();
    expect(requests.single.uri.path, '/api/v1/auth/steam/login-url');
    expect(requests.single.queryParameters['platform'], 'mobile');
    expect(requests.single.extra['withCredentials'], isTrue);
    expect(launched!.host, 'steamcommunity.com');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('login URL supports the deployed backend data.url field', () async {
    loginUrlField = 'url';
    final url = await AuthService(client: client).getLoginUrl('web');
    expect(url.host, 'steamcommunity.com');
    expect(requests.single.queryParameters['platform'], 'web');
    expect(requests.single.extra['withCredentials'], isTrue);
  });

  test('public login URL never attaches a stored expired token', () async {
    await client.store.save('expired-token', steamId);
    await AuthService(client: client).getLoginUrl('web');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(await client.store.readToken(), 'expired-token');
  });

  test(
    'callback verifies session and merges real identity without losing stats',
    () async {
      final notifier = AuthNotifier(AuthService(client: client));
      addTearDown(notifier.dispose);
      await notifier.handleAuthCallback(
        Uri.parse('hunt1896://auth/steam?token=test-token&steam_id=$steamId'),
      );
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.steamId, steamId);
      expect(
        requests.every(
          (r) => r.headers['Authorization'] == 'Bearer test-token',
        ),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SessionStore.steamIdKey), steamId);
      final summary = await PlayerService(client: client)
          .fetchPlayerSummary(steamId);
      expect(summary.personaName, 'Real Hunter');
      final restored = await AuthService(client: client).restoreSession();
      expect(restored!.steamId, steamId);
    },
  );

  test('401 clears persisted session and resets notifier silently', () async {
    await client.store.save('expired-token', steamId);
    unauthorized = true;
    final notifier = AuthNotifier(AuthService(client: client));
    addTearDown(notifier.dispose);
    await notifier.restoreSession();
    expect(await client.store.readToken(), isNull);
    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(notifier.state.error, isNull);
  });

  test(
    'authenticated backend flag restores the session and preserves token',
    () async {
      sessionFlag = 'authenticated';
      final notifier = AuthNotifier(AuthService(client: client));
      addTearDown(notifier.dispose);
      await notifier.handleAuthCallback(
        Uri.parse('hunt1896://auth/steam?token=test-token&steam_id=$steamId'),
      );
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.steamId, steamId);
      expect(await client.store.readToken(), 'test-token');
    },
  );

  test('authenticated false clears an invalid session', () async {
    sessionFlag = 'authenticated';
    valid = false;
    await client.store.save('invalid-token', steamId);
    expect(await AuthService(client: client).restoreSession(), isNull);
    expect(await client.store.readToken(), isNull);
  });

  test('invalid session is cleared without fetching a summary', () async {
    await client.store.save('invalid-token', steamId);
    valid = false;
    expect(await AuthService(client: client).restoreSession(), isNull);
    expect(await client.store.readToken(), isNull);
    expect(requests.length, 1);
  });

  test(
    'legacy token migrates to auth_token and 401 removes cached identity',
    () async {
      SharedPreferences.setMockInitialValues({
        'steam_token': 'legacy',
        'user_info': 'cached',
        SessionStore.steamIdKey: steamId,
      });
      expect(await client.store.readToken(), 'legacy');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'legacy');
      expect(prefs.containsKey('steam_token'), isFalse);
      unauthorized = true;
      await expectLater(
        client.get('/auth/session'),
        throwsA(isA<DioException>()),
      );
      expect(prefs.containsKey('auth_token'), isFalse);
      expect(prefs.containsKey('user_info'), isFalse);
      expect(prefs.containsKey(SessionStore.steamIdKey), isFalse);
    },
  );

  test('untrusted callbacks never write a token', () async {
    final service = AuthService(client: client);
    for (final uri in [
      'https://evil.example/auth/steam?token=x&steam_id=$steamId',
      'hunt1896://auth/steam?token=x&steam_id=123',
      'hunt1896://auth/steam?token=x&token=y&steam_id=$steamId',
    ]) {
      await expectLater(
        service.handleAuthCallback(Uri.parse(uri)),
        throwsFormatException,
      );
      expect(await client.store.readToken(), isNull);
    }
    expect(requests, isEmpty);
  });

  testWidgets('verified callback updates header and logout resets identity', (
    tester,
  ) async {
    final notifier = AuthNotifier(AuthService(client: client));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authProvider.overrideWith((ref) => notifier),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('使用 Steam 登录'), findsOneWidget);
    await tester.runAsync(
      () => notifier.handleAuthCallback(
        Uri.parse('hunt1896://auth/steam?token=test-token&steam_id=$steamId'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Real Hunter'), findsOneWidget);
    expect(find.text('退出 Steam 登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(notifier.logout);
    await tester.pumpAndSettle();
    expect(find.text('Real Hunter'), findsNothing);
    expect(find.text('使用 Steam 登录'), findsOneWidget);
    expect(await client.store.readToken(), isNull);
  });
}
