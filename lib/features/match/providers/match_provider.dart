import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/match_record.dart';
import '../../../services/hunter_api_service.dart';
import '../../auth/auth_provider.dart';
import '../../../models/match_filter.dart';

final matchFilterProvider = StateProvider.autoDispose<MatchFilter>(
  (ref) => MatchFilter.all,
);

final matchProvider =
    StateNotifierProvider.autoDispose<MatchNotifier, AsyncValue<MatchHistory>>((
      ref,
    ) {
      final session = ref.watch(
        authProvider.select((auth) => (auth.status, auth.steamId, auth.token)),
      );
      final notifier = MatchNotifier(
        service: ref.watch(hunterApiServiceProvider),
        steamId: session.$1 == AuthStatus.authenticated ? session.$2 : null,
        filter: ref.watch(matchFilterProvider),
      );
      unawaited(notifier.refresh());
      return notifier;
    });

class MatchHistory {
  const MatchHistory({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });
  final List<MatchRecord> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;
}

class MatchNotifier extends StateNotifier<AsyncValue<MatchHistory>> {
  MatchNotifier({
    required this.service,
    required this.steamId,
    required this.filter,
    this.pageSize = 20,
  }) : super(const AsyncLoading());
  final HunterApiService service;
  final String? steamId;
  final MatchFilter filter;
  final int pageSize;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    if (steamId == null) {
      state = const AsyncData(MatchHistory());
      return;
    }
    state = const AsyncLoading();
    try {
      final page = await service.fetchMatchHistory(
        steamId!,
        page: 1,
        size: pageSize,
        filter: filter,
      );
      if (!mounted || generation != _generation) return;
      state = AsyncData(
        MatchHistory(
          items: _unique(page.items),
          page: page.page,
          hasMore: page.hasMore,
        ),
      );
    } catch (error, stack) {
      if (mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> loadMore() async {
    final previous = state.asData?.value;
    if (steamId == null ||
        previous == null ||
        previous.loadingMore ||
        !previous.hasMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      MatchHistory(
        items: previous.items,
        page: previous.page,
        hasMore: previous.hasMore,
        loadingMore: true,
      ),
    );
    try {
      final page = await service.fetchMatchHistory(
        steamId!,
        page: previous.page + 1,
        size: pageSize,
        filter: filter,
      );
      if (!mounted || generation != _generation) return;
      state = AsyncData(
        MatchHistory(
          items: _unique([...previous.items, ...page.items]),
          page: page.page,
          hasMore: page.hasMore,
        ),
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = AsyncData(
        MatchHistory(
          items: previous.items,
          page: previous.page,
          hasMore: previous.hasMore,
          loadMoreError: error,
        ),
      );
    }
  }

  List<MatchRecord> _unique(List<MatchRecord> items) {
    final seen = <String>{};
    return List.unmodifiable(items.where((item) => seen.add(item.matchId)));
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
