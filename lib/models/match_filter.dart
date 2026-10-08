import 'match_record.dart';

enum MatchFilter {
  all('全部对局'),
  extracted('仅撤离成功'),
  dead('仅阵亡');

  const MatchFilter(this.label);
  final String label;

  /// Pass to `records.where(filter.matches)` to filter history.
  bool matches(MatchRecord record) => switch (this) {
    MatchFilter.all => true,
    MatchFilter.extracted => record.extracted,
    MatchFilter.dead => !record.extracted,
  };
}
