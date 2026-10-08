import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunt/core/network/api_client.dart';
import 'package:hunt/features/auth/auth_provider.dart';
import 'package:hunt/features/match/widgets/match_card.dart';
import 'package:hunt/features/match/widgets/match_filter_bar.dart';
import 'package:hunt/main.dart';

import 'fixtures/api_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('API page fits $width / $scale and filters on server', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = ApiFixture();
        final auth = (await tester.runAsync(fixture.authenticate))!;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fixture.client),
              authProvider.overrideWith((ref) => auth),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('API Hunter'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2200),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MatchFilterBar).hitTestable(), findsOneWidget);
        await tester.tap(find.text('仅撤离成功'));
        await tester.pumpAndSettle();
        expect(
          fixture.requests
              .lastWhere((r) => r.path.endsWith('/matches'))
              .queryParameters,
          {'page': 1, 'size': 20, 'filter': 'extracted'},
        );
        for (final card in tester.widgetList<MatchCard>(
          find.byType(MatchCard),
        )) {
          expect(card.record.extracted, isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('pull to refresh reloads stats and history', (tester) async {
    final fixture = ApiFixture();
    final auth = (await tester.runAsync(fixture.authenticate))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fixture.client),
          authProvider.overrideWith((ref) => auth),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    final before = fixture.requests
        .where((r) => r.path.endsWith('/matches'))
        .length;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((r) => r.path.endsWith('/matches')).length,
      before + 1,
    );
    expect(fixture.requests.where((r) => r.path.endsWith('/stats')).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest never requests hunter data or displays sample records', (
    tester,
  ) async {
    final fixture = ApiFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fixture.client)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('使用 Steam 登录'), findsOneWidget);
    expect(find.byType(MatchCard), findsNothing);
    expect(fixture.requests, isEmpty);
  });
}
