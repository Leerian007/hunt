import 'package:json_annotation/json_annotation.dart';

part 'match_record.g.dart';

/// A single historical Bounty Hunt match.
@JsonSerializable()
class MatchRecord {
  const MatchRecord({
    required this.matchId,
    required this.matchTime,
    required this.mapName,
    required this.extracted,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.teamWipes,
    required this.bountyExtracted,
    required this.mmr,
    required this.mmrStars,
    required this.mmrChange,
  });

  factory MatchRecord.fromJson(Map<String, dynamic> json) =>
      _$MatchRecordFromJson(json);

  @JsonKey(name: 'match_id')
  final String matchId;
  @JsonKey(name: 'match_time')
  final DateTime matchTime;
  @JsonKey(name: 'map_name')
  final String mapName;
  final bool extracted;
  final int kills;
  final int deaths;
  final int assists;
  @JsonKey(name: 'team_wipes')
  final int teamWipes;
  @JsonKey(name: 'bounty_extracted')
  final int bountyExtracted;
  final int mmr;
  @JsonKey(name: 'mmr_stars')
  final int? mmrStars;
  @JsonKey(name: 'mmr_change')
  final int mmrChange;

  Map<String, dynamic> toJson() => _$MatchRecordToJson(this);
}
