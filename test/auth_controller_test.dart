import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunt/core/network/api_client.dart';
import 'package:hunt/features/auth/auth_provider.dart';
import 'package:hunt/services/auth_service.dart';
import 'package:hunt/main.dart';

import 'fixtures/api_fixture.dart';

const id = '76561198012345678';
final callback = Uri.parse(
  'hunt1896://auth/steam?token=callback-token&steam_id=$id',
);

class DelayedSessionService extends AuthService {
  DelayedSessionService(ApiClient superClient) : super(client: superClient);
  final result = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> verifySession() => result.future;
}

Map<String, dynamic> validSession() => {
  'valid': true,
  'steam_id': id,
  'expires_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cold callback is processed once despite duplicate link delivery',
    () async {
      final fixture = ApiFixture();
      final links = StreamController<Uri>.broadcast(sync: true);
      addTearDown(links.close);
      final controller = AuthNotifier(
        AuthService(client: fixture.client),
        links: links.stream,
        initialLink: () async => callback,
      );
      addTearDown(controller.dispose);
      final startup = controller.initialize();
      links.add(callback);
      await startup;
      await controller.handleAuthCallback(callback);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(await fixture.client.store.readToken(), 'callback-token');
      expect(
        fixture.requests.where((r) => r.path == '/auth/session').length,
        1,
      );
      expect(fixture.requests.any((r) => r.path.endsWith('/summary')), isFalse);
    },
  );

  test('foreground link signs in and subscriptions stop on disposal', () async {
    final fixture = ApiFixture();
    final links = StreamController<Uri>.broadcast(sync: true);
    addTearDown(links.close);
    final controller = AuthNotifier(
      AuthService(client: fixture.client),
      links: links.stream,
      initialLink: () async => null,
    );
    await controller.initialize();
    expect(controller.state.status, AuthStatus.unauthenticated);
    links.add(Uri.parse('hunt1896://wrong/steam?token=x&steam_id=$id'));
    expect(fixture.requests, isEmpty);
    links.add(callback);
    await controller.handleAuthCallback(callback);
    expect(controller.state.status, AuthStatus.authenticated);
    controller.dispose();
    final count = fixture.requests.length;
    links.add(callback);
    expect(fixture.requests.length, count);
  });

  test(
    'restoration timeout leaves guest state and ignores a late success',
    () async {
      final fixture = ApiFixture();
      await fixture.client.store.save('saved-token', id);
      final service = DelayedSessionService(fixture.client);
      final controller = AuthNotifier(
        service,
        sessionTimeout: const Duration(milliseconds: 20),
        links: const Stream.empty(),
        initialLink: () async => null,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.error, contains('超时'));
      service.result.complete(validSession());
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, AuthStatus.unauthenticated);
    },
  );

  testWidgets(
    'startup splash waits for verification before showing the profile',
    (tester) async {
      final fixture = ApiFixture();
      await fixture.client.store.save('saved-token', id);
      final service = DelayedSessionService(fixture.client);
      final controller = AuthNotifier(
        service,
        links: const Stream.empty(),
        initialLink: () async => null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fixture.client),
            authProvider.overrideWith((ref) => controller),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pump();
      expect(find.text('正在恢复 Steam 会话…'), findsOneWidget);
      expect(find.text('使用 Steam 登录'), findsNothing);
      service.result.complete(validSession());
      await tester.pumpAndSettle();
      expect(find.text('正在恢复 Steam 会话…'), findsNothing);
      expect(find.text('API Hunter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
