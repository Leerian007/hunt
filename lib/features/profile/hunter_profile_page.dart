import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/auth_provider.dart';
import '../match/providers/match_provider.dart';
import '../match/widgets/match_card.dart';
import '../match/widgets/match_filter_bar.dart';
import 'providers/profile_provider.dart';
import 'widgets/hunter_profile_header.dart';

class HunterProfilePage extends ConsumerStatefulWidget {
  const HunterProfilePage({super.key});
  @override
  ConsumerState<HunterProfilePage> createState() => _HunterProfilePageState();
}

class _HunterProfilePageState extends ConsumerState<HunterProfilePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadNearBottom);
  }

  void _loadNearBottom() {
    if (!mounted || !_scroll.hasClients || _scroll.position.extentAfter > 300) {
      return;
    }
    final history = ref.read(matchProvider).asData?.value;
    if (history != null &&
        history.hasMore &&
        !history.loadingMore &&
        history.loadMoreError == null) {
      unawaited(ref.read(matchProvider.notifier).loadMore());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      await ref.read(authProvider.notifier).restoreSession();
      return;
    }
    // Both providers retain their own errors for in-place retries.
    await Future.wait([
      ref
          .refresh(profileProvider.future)
          .then<void>((_) {}, onError: (Object _, StackTrace stack) {}),
      ref.read(matchProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final matches = ref.watch(matchProvider);
    final filter = ref.watch(matchFilterProvider);
    final loggedIn = auth.status == AuthStatus.authenticated;
    final painter = TextPainter(
      text: TextSpan(
        text: '仅撤离成功',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final filterHeight = math.max(48.0, painter.height + 20) + 24;
    painter.dispose();
    if (loggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNearBottom());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('猎人档案')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 832),
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFFD5BC86),
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: !loggedIn
                          ? _loginPanel(auth)
                          : profile.when(
                              skipLoadingOnRefresh: false,
                              skipLoadingOnReload: false,
                              loading: () => const _StatusPanel(
                                message: '正在同步猎人资料…',
                                loading: true,
                              ),
                              error: (_, stack) => _StatusPanel(
                                message: '猎人资料加载失败',
                                onRetry: () => ref.invalidate(profileProvider),
                              ),
                              data: (value) => value == null
                                  ? _loginPanel(auth)
                                  : HunterProfileHeader(
                                      profile: value,
                                      authStatus: auth.status,
                                      onLogin: ref
                                          .read(authProvider.notifier)
                                          .loginWithSteam,
                                      onLogout: ref
                                          .read(authProvider.notifier)
                                          .logout,
                                    ),
                            ),
                    ),
                  ),
                  if (loggedIn) ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FilterHeaderDelegate(
                        extent: filterHeight,
                        background: Theme.of(context).scaffoldBackgroundColor,
                        filter: filter,
                        onChanged: (value) =>
                            ref.read(matchFilterProvider.notifier).state =
                                value,
                      ),
                    ),
                    matches.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () => const SliverToBoxAdapter(
                        child: _StatusPanel(message: '正在加载战绩…', loading: true),
                      ),
                      error: (_, stack) => SliverToBoxAdapter(
                        child: _StatusPanel(
                          message: '战绩加载失败',
                          onRetry: ref.read(matchProvider.notifier).refresh,
                        ),
                      ),
                      data: (history) => SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.builder(
                          itemCount: history.items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == history.items.length) {
                              if (history.loadingMore) {
                                return const _StatusPanel(
                                  message: '正在加载更多…',
                                  loading: true,
                                );
                              }
                              if (history.loadMoreError != null) {
                                return _StatusPanel(
                                  message: '加载更多失败，已有战绩已保留',
                                  onRetry: ref
                                      .read(matchProvider.notifier)
                                      .loadMore,
                                );
                              }
                              if (history.hasMore) {
                                return Center(
                                  child: TextButton(
                                    onPressed: ref
                                        .read(matchProvider.notifier)
                                        .loadMore,
                                    child: const Text('加载更多'),
                                  ),
                                );
                              }
                              return _StatusPanel(
                                message: history.items.isEmpty
                                    ? '暂无符合条件的战绩'
                                    : '已显示全部战绩',
                              );
                            }
                            return Padding(
                              key: ValueKey(history.items[index].matchId),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MatchCard(record: history.items[index]),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginPanel(AuthState auth) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF20262B), Color(0xFF091720)],
      ),
    ),
    child: Column(
      children: [
        const Text(
          '登录查看猎人档案',
          style: TextStyle(fontSize: 22, color: Color(0xFFD5BC86)),
        ),
        const SizedBox(height: 20),
        if (auth.status == AuthStatus.authenticating)
          const CircularProgressIndicator(color: Color(0xFFD5BC86))
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF171D25),
              foregroundColor: Colors.white,
            ),
            onPressed: ref.read(authProvider.notifier).loginWithSteam,
            icon: SvgPicture.asset(
              'assets/icons/steam_logo.svg',
              width: 52,
              height: 22,
            ),
            label: const Text('使用 Steam 登录'),
          ),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          Text(auth.error!, style: const TextStyle(color: Color(0xFFFF7C87))),
          TextButton(
            onPressed: ref.read(authProvider.notifier).restoreSession,
            child: const Text('重试恢复会话'),
          ),
        ],
      ],
    ),
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFADBAC1)),
        ),
        if (onRetry != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF233039),
              foregroundColor: const Color(0xFFD5BC86),
              minimumSize: const Size(96, 48),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
      ],
    ),
  );
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({
    required this.extent,
    required this.background,
    required this.filter,
    required this.onChanged,
  });
  final double extent;
  final Color background;
  final MatchFilter filter;
  final ValueChanged<MatchFilter> onChanged;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: background,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // Keep all choices accessible without wrapping inside a fixed sliver.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: MatchFilterBar(selectedFilter: filter, onChanged: onChanged),
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent ||
      background != oldDelegate.background ||
      filter != oldDelegate.filter ||
      onChanged != oldDelegate.onChanged;
}
