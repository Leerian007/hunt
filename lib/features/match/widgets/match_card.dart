import 'package:flutter/material.dart';

import '../../../models/match_record.dart';

/// A history entry. [now] optionally fixes the clock for previews and tests.
/// Relative time is refreshed whenever this widget rebuilds.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.record, this.now});

  final MatchRecord record;
  final DateTime? now;

  static const _muted = Color(0xFFADBAC1);
  static const _gold = Color(0xFFD5BC86);

  @override
  Widget build(BuildContext context) {
    final accent = record.extracted
        ? const Color(0xFF65DEC5)
        : const Color(0xFFFF7C87);
    final darkAccent = record.extracted
        ? const Color(0xFF123D36)
        : const Color(0xFF451F2A);
    final changeColor = record.mmrChange > 0
        ? const Color(0xFF65DEC5)
        : record.mmrChange < 0
        ? const Color(0xFFFF7C87)
        : _muted;
    final change = record.mmrChange > 0
        ? '+${record.mmrChange}'
        : '${record.mmrChange}';

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.mapName,
          style: const TextStyle(
            color: Color(0xFFF6F3EA),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              record.extracted ? '成功撤离' : '阵亡',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Tooltip(
              message: record.matchTime.toLocal().toString(),
              child: Text(
                _relativeTime(record.matchTime, now ?? DateTime.now()),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'K / D / A',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
            Semantics(
              label:
                  '击杀 ${record.kills}，死亡 ${record.deaths}，助攻 ${record.assists}',
              excludeSemantics: true,
              child: Text(
                '${record.kills} / ${record.deaths} / ${record.assists}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    Widget rewards(bool compact) => Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Wrap(
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            _RewardBadge(
              icon: Icons.monetization_on_outlined,
              text: '赏金 ${record.bountyExtracted}',
              color: _gold,
            ),
            _RewardBadge(
              icon: Icons.groups_outlined,
              text: '灭队 ${record.teamWipes}',
              color: _muted,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'MMR $change',
          style: TextStyle(
            color: changeColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .18)),
        gradient: LinearGradient(
          colors: [darkAccent, const Color(0xFF111C24)],
          stops: const [0, .45],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 4,
            child: ColoredBox(color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final compact = constraints.maxWidth < 480 * textScale;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      details,
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFF354149)),
                      ),
                      rewards(true),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 20),
                    Expanded(child: rewards(false)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime time, DateTime now) {
    final elapsed = now.difference(time);
    if (elapsed.isNegative || elapsed.inMinutes == 0) return '刚刚';
    if (elapsed.inHours == 0) return '${elapsed.inMinutes}分钟前';
    if (elapsed.inDays == 0) return '${elapsed.inHours}小时前';
    return '${elapsed.inDays}天前';
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 16, color: color),
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: TextStyle(color: color, fontSize: 12),
    ),
  );
}
