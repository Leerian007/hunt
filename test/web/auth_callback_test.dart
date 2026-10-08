@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:hunt/features/auth/auth_provider.dart';
import 'package:hunt/services/auth_service.dart';

import '../fixtures/api_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'web callback restores session and removes credentials from the address',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = web.window.location.href;
      addTearDown(() => web.window.history.replaceState(null, '', original));
      final fixture = ApiFixture();
      web.window.history.replaceState(
        null,
        '',
        '/auth/callback?token=web-token&steam_id=76561198012345678',
      );
      final callback = Uri.parse(web.window.location.href);
      final controller = AuthNotifier(
        AuthService(client: fixture.client),
        links: const Stream.empty(),
        initialLink: () async => callback,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.state.status, AuthStatus.authenticated);
      expect(await fixture.client.store.readToken(), 'web-token');
      expect(
        Uri.parse(web.window.location.href).queryParameters
            .containsKey('token'),
        isFalse,
      );
      expect(
        Uri.parse(web.window.location.href).queryParameters
            .containsKey('steam_id'),
        isFalse,
      );
    },
  );
}
