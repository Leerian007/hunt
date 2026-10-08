// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchRecord _$MatchRecordFromJson(Map<String, dynamic> json) => MatchRecord(
  matchId: json['match_id'] as String,
  matchTime: DateTime.parse(json['match_time'] as String),
  mapName: json['map_name'] as String,
  extracted: json['extracted'] as bool,
  kills: (json['kills'] as num).toInt(),
  deaths: (json['deaths'] as num).toInt(),
  assists: (json['assists'] as num).toInt(),
  teamWipes: (json['team_wipes'] as num).toInt(),
  bountyExtracted: (json['bounty_extracted'] as num).toInt(),
  mmr: (json['mmr'] as num).toInt(),
  mmrStars: (json['mmr_stars'] as num).toInt(),
  mmrChange: (json['mmr_change'] as num).toInt(),
);

Map<String, dynamic> _$MatchRecordToJson(MatchRecord instance) =>
    <String, dynamic>{
      'match_id': instance.matchId,
      'match_time': instance.matchTime.toIso8601String(),
      'map_name': instance.mapName,
      'extracted': instance.extracted,
      'kills': instance.kills,
      'deaths': instance.deaths,
      'assists': instance.assists,
      'team_wipes': instance.teamWipes,
      'bounty_extracted': instance.bountyExtracted,
      'mmr': instance.mmr,
      'mmr_stars': instance.mmrStars,
      'mmr_change': instance.mmrChange,
    };
