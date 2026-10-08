import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/player_profile.dart';
import '../../auth/auth_provider.dart';

enum HunterProfileTab { power, weaponTraits }

/// Responsive profile hero. Rates in [profile] are fractions from 0 to 1.
///
/// Replace [hunterImageUrl] with a full-body hunter cutout when art is available.
/// [onTabChanged] lets the parent switch the content below this header.
class HunterProfileHeader extends StatefulWidget {
  const HunterProfileHeader({
    super.key,
    required this.profile,
    this.hunterImageUrl =
        'https://placehold.co/600x1000/16252d/c7ad78/png?text=HUNTER',
    this.initialTab = HunterProfileTab.power,
    this.onTabChanged,
    this.authStatus = AuthStatus.unauthenticated,
    this.authError,
    this.onLogin,
    this.onLogout,
  });

  final PlayerProfile profile;
  final String hunterImageUrl;
  final HunterProfileTab initialTab;
  final ValueChanged<HunterProfileTab>? onTabChanged;
  final AuthStatus authStatus;
  final String? authError;
  final VoidCallback? onLogin;
  final VoidCallback? onLogout;

  @override
  State<HunterProfileHeader> createState() => _HunterProfileHeaderState();
}

class _HunterProfileHeaderState extends State<HunterProfileHeader> {
  static const _gold = Color(0xFFD5BC86);
  static const _muted = Color(0xFFADBAC1);
  late HunterProfileTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 400;
            final padding = narrow ? 16.0 : 28.0;
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final rowHeight = math.max(110.0, 110 * scale);
            return Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _gold.withValues(alpha: .18)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF20262B),
                    Color(0xFF091720),
                    Color(0xFF10191D),
                  ],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onLogin != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF171D25),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed:
                                widget.authStatus == AuthStatus.authenticating
                                ? null
                                : widget.authStatus == AuthStatus.authenticated
                                ? widget.onLogout
                                : widget.onLogin,
                            icon: widget.authStatus == AuthStatus.authenticating
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _gold,
                                    ),
                                  )
                                : SvgPicture.asset(
                                    'assets/icons/steam_logo.svg',
                                    width: 52,
                                    height: 22,
                                    placeholderBuilder: (_) => const Icon(
                                      Icons.account_circle_outlined,
                                    ),
                                    errorBuilder: (_, error, stack) =>
                                        const Icon(
                                          Icons.account_circle_outlined,
                                        ),
                                  ),
                            label: Text(
                              widget.authStatus == AuthStatus.authenticating
                                  ? '正在连接…'
                                  : widget.authStatus ==
                                        AuthStatus.authenticated
                                  ? '退出 Steam 登录'
                                  : '使用 Steam 登录',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '猎人生涯 · Steam 账号资料',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        if (widget.authError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.authError!,
                              style: const TextStyle(
                                color: Color(0xFFFF7C87),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          ClipOval(
                            child: Image.network(
                              profile.avatarUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) => const SizedBox(
                                width: 52,
                                height: 52,
                                child: Icon(
                                  Icons.person_outline,
                                  color: _gold,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.nickname,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'STEAM  ${profile.steamId}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFF374047), height: 1),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: rowHeight * 4,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(0, .35),
                                    radius: .8,
                                    colors: [
                                      const Color(0xFF50717A)
                                          .withValues(alpha: .48),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              left: constraints.maxWidth * .23,
                              right: constraints.maxWidth * .23,
                              child: _HunterArtwork(url: widget.hunterImageUrl),
                            ),
                            Column(
                              children: [
                                _metricRow(
                                  rowHeight,
                                  _Metric(
                                    label: 'MMR 星级',
                                    value: profile.mmrStars == null
                                        ? '—'
                                        : '${profile.mmrStars} 星猎人',
                                    gold: true,
                                    decoration: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 1,
                                      children: List.generate(
                                        6,
                                        (index) => Icon(
                                          index < (profile.mmrStars ?? 0)
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: _gold,
                                          size: narrow ? 12 : 17,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _Metric(
                                    label: '招牌武器',
                                    value: profile.signatureWeapon ?? '—',
                                    compact: true,
                                    decoration: const Icon(
                                      Icons.gps_fixed,
                                      color: _gold,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                _metricRow(
                                  rowHeight,
                                  _Metric(
                                    label:
                                        '猎人等级 / 转生 ${profile.prestige ?? '—'}',
                                    value: profile.hunterLevel == null
                                        ? '—'
                                        : 'Lv.${profile.hunterLevel}',
                                  ),
                                  _Metric(
                                    label: '生涯 KDA',
                                    value:
                                        profile.kda?.toStringAsFixed(2) ?? '—',
                                  ),
                                ),
                                _metricRow(
                                  rowHeight,
                                  _Metric(
                                    label: '游玩时长',
                                    value: profile.playHours == null
                                        ? '—'
                                        : '${profile.playHours!.toStringAsFixed(1)}h',
                                  ),
                                  _Metric(
                                    label: '撤离胜率',
                                    value: profile.winRate == null
                                        ? '—'
                                        : '${(profile.winRate! * 100).toStringAsFixed(1)}%',
                                  ),
                                ),
                                _metricRow(
                                  rowHeight,
                                  _Metric(
                                    label: '场均 ACS',
                                    value:
                                        profile.acs?.toStringAsFixed(1) ?? '—',
                                  ),
                                  _Metric(
                                    label: '爆头精准度',
                                    value: profile.headshotRate == null
                                        ? '—'
                                        : '${(profile.headshotRate! * 100).toStringAsFixed(1)}%',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (profile.totalKills != null ||
                          profile.totalExtractions != null ||
                          profile.totalBounty != null)
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _Metric(
                              label: '生涯击杀',
                              value: '${profile.totalKills ?? '—'}',
                            ),
                            _Metric(
                              label: '累计撤离',
                              value: '${profile.totalExtractions ?? '—'}',
                            ),
                            _Metric(
                              label: '累计赏金',
                              value: '${profile.totalBounty ?? '—'}',
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF233039),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _gold.withValues(alpha: .2),
                          ),
                        ),
                        child: Row(
                          children: [
                            _tabButton(HunterProfileTab.power, '个人战力'),
                            _tabButton(HunterProfileTab.weaponTraits, '武器特质'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _metricRow(double height, Widget left, Widget right) => SizedBox(
    height: height,
    child: Row(
      children: [
        Expanded(flex: 3, child: left),
        const Spacer(flex: 4),
        Expanded(flex: 3, child: right),
      ],
    ),
  );

  Widget _tabButton(HunterProfileTab tab, String label) {
    final selected = _tab == tab;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: selected ? const Color(0xFF131C22) : _muted,
            backgroundColor: selected ? _gold : Colors.transparent,
            minimumSize: const Size(0, 48),
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            if (_tab == tab) return;
            setState(() => _tab = tab);
            widget.onTabChanged?.call(tab);
          },
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.gold = false,
    this.compact = false,
    this.decoration,
  });

  final String label;
  final String value;
  final bool gold;
  final bool compact;
  final Widget? decoration;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (decoration != null) ...[decoration!, const SizedBox(height: 6)],
      Text(
        value,
        textAlign: TextAlign.center,
        maxLines: compact ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: gold ? const Color(0xFFD5BC86) : const Color(0xFFF6F3EA),
          fontSize: compact ? 12 : 23,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFADBAC1), fontSize: 11),
      ),
    ],
  );
}

class _HunterArtwork extends StatelessWidget {
  const _HunterArtwork({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: .72,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, .13, .74, 1],
        ).createShader(bounds),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const _HunterPlaceholder(),
          errorBuilder: (_, error, stack) => const _HunterPlaceholder(),
        ),
      ),
    ),
  );
}

class _HunterPlaceholder extends StatelessWidget {
  const _HunterPlaceholder();

  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.contain,
    child: Icon(
      Icons.accessibility_new_rounded,
      color: Color(0xFF7C8F95),
      size: 240,
    ),
  );
}
