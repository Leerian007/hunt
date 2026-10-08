import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunt/features/auth/auth_provider.dart';
import 'package:hunt/features/profile/providers/profile_provider.dart';
import 'package:hunt/features/match/providers/match_provider.dart';
import 'package:hunt/features/match/widgets/match_filter_bar.dart';
import 'package:hunt/services/hunter_api_service.dart';
import 'package:hunt/services/player_service.dart';
import 'package:hunt/models/match_record.dart';

import 'fixtures/api_fixture.dart';
import 'fixtures/mock_hunter_service.dart';

class ControlledService extends HunterApiService {
  final requests =
      <({int page, MatchFilter filter, Completer<MatchPage> result})>[];
  final summary = Completer<SteamPlayer>();
  final stats = Completer<PlayerStats>();
  bool summaryStarted = false;
  bool statsStarted = false;
  @override
  Future<SteamPlayer> fetchPlayerSummary(String steamId) {
    summaryStarted = true;
    return summary.future;
  }

  @override
  Future<PlayerStats> fetchPlayerStats(String steamId) {
    statsStarted = true;
    return stats.future;
  }

  @override
  Future<MatchPage> fetchMatchHistory(
    String steamId, {
    required int page,
    int size = 20,
    MatchFilter filter = MatchFilter.all,
  }) {
    final result = Completer<MatchPage>();
    requests.add((page: page, filter: filter, result: result));
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final records = const MockHunterService().matchHistory;

  test('backend match record without historical stars is accepted', () {
    final json = records.first.toJson()..remove('mmr_stars');
    final record = MatchRecord.fromJson(json);
    expect(record.mmrStars, isNull);
    expect(record.matchId, records.first.matchId);
  });

  test(
    'profile requests summary and stats concurrently; absent metrics stay null',
    () async {
      final auth = await ApiFixture().authenticate();
      final service = ControlledService();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          hunterApiServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(profileProvider, (_, next) {});
      addTearDown(subscription.close);
      final future = container.read(profileProvider.future);
      expect(service.summaryStarted, isTrue);
      expect(service.statsStarted, isTrue);
      service.summary.complete(
        const SteamPlayer(
          steamId: '76561198012345678',
          personaName: 'Real',
          avatarFull: 'https://example.com/avatar.jpg',
        ),
      );
      service.stats.complete(
        const PlayerStats({
          'total_kills': 300,
          'extracted_matches': 90,
          'total_bounty_extracted': 50000,
          'mmr_stars': 5,
        }),
      );
      final result = (await future)!;
      expect(result.nickname, 'Real');
      expect(result.totalKills, 300);
      expect(result.mmrStars, 5);
      expect(result.kda, isNull);
    },
  );

  test('pagination guards concurrent loads, deduplicates and retries the same page', () async {
    final service = ControlledService();
    final notifier = MatchNotifier(
      service: service,
      steamId: '76561198012345678',
      filter: MatchFilter.dead,
    );
    addTearDown(notifier.dispose);
    final first = notifier.refresh();
    service.requests.last.result.complete(
      MatchPage(items: records.take(2).toList(), page: 1, hasMore: true),
    );
    await first;
    final more = notifier.loadMore();
    await notifier.loadMore();
    expect(service.requests.length, 2);
    service.requests.last.result.completeError(Exception('offline'));
    await more;
    expect(notifier.state.requireValue.items.length, 2);
    expect(notifier.state.requireValue.loadMoreError, isNotNull);
    final retry = notifier.loadMore();
    expect(service.requests.last.page, 2);
    expect(service.requests.last.filter, MatchFilter.dead);
    service.requests.last.result.complete(
      MatchPage(items: records.sublist(1), page: 2, hasMore: false),
    );
    await retry;
    expect(notifier.state.requireValue.items.length, 5);
    await notifier.loadMore();
    expect(service.requests.length, 3);
  });

  test('refresh discards an in-flight previous page response', () async {
    final service = ControlledService();
    final notifier = MatchNotifier(
      service: service,
      steamId: '76561198012345678',
      filter: MatchFilter.all,
    );
    addTearDown(notifier.dispose);
    final first = notifier.refresh();
    service.requests[0].result.complete(
      MatchPage(items: [records.first], page: 1, hasMore: true),
    );
    await first;
    final more = notifier.loadMore();
    final refresh = notifier.refresh();
    service.requests[2].result.complete(
      MatchPage(items: [records.last], page: 1, hasMore: false),
    );
    await refresh;
    service.requests[1].result.complete(
      MatchPage(items: records, page: 2, hasMore: true),
    );
    await more;
    expect(
      notifier.state.requireValue.items.single.matchId,
      records.last.matchId,
    );
    expect(notifier.state.requireValue.page, 1);
  });
}
