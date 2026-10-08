import 'package:dio/dio.dart';
import 'package:hunt/core/network/api_client.dart';
import 'package:hunt/features/auth/auth_provider.dart';
import 'package:hunt/services/auth_service.dart';

import 'mock_hunter_service.dart';

class ApiFixture {
  ApiFixture() {
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final profile = const MockHunterService().profile;
          Map<String, dynamic> data;
          if (request.path.endsWith('/session')) {
            data = {
              'valid': true,
              'steam_id': profile.steamId,
              'expires_at': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            };
          } else if (request.path.endsWith('/summary')) {
            data = {
              'steam_id': profile.steamId,
              'persona_name': 'API Hunter',
              'avatar_full': 'https://example.com/avatar.jpg',
            };
          } else if (request.path.endsWith('/stats')) {
            data = {
              ...profile.toJson(),
              'total_kills': 123,
              'extracted_matches': 45,
              'total_bounty_extracted': 6700,
            };
          } else if (request.path.endsWith('/matches')) {
            final filter = request.queryParameters['filter'];
            final rows = const MockHunterService().matchHistory
                .where(
                  (m) =>
                      filter == 'all' ||
                      (filter == 'extracted' ? m.extracted : !m.extracted),
                )
                .toList();
            final page = request.queryParameters['page'] as int;
            final size = request.queryParameters['size'] as int;
            data = {
              'list': rows
                  .skip((page - 1) * size)
                  .take(size)
                  .map((m) => m.toJson())
                  .toList(),
              'total': rows.length,
              'pages': (rows.length / size).ceil(),
            };
          } else {
            handler.reject(
              DioException(
                requestOptions: request,
                error: 'Unexpected fixture endpoint',
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: 200,
              data: {'code': 0, 'data': data},
            ),
          );
        },
      ),
    );
  }
  final client = ApiClient(
    dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1')),
  );
  final requests = <RequestOptions>[];

  Future<AuthNotifier> authenticate() async {
    final notifier = AuthNotifier(AuthService(client: client));
    await notifier.handleAuthCallback(
      Uri.parse(
        'hunt1896://auth/steam?token=fixture-token&steam_id=76561198012345678',
      ),
    );
    return notifier;
  }
}
