// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerProfile _$PlayerProfileFromJson(Map<String, dynamic> json) =>
    PlayerProfile(
      nickname: json['nickname'] as String,
      steamId: json['steam_id'] as String,
      avatarUrl: json['avatar_url'] as String,
      mmrStars: (json['mmr_stars'] as num).toInt(),
      hunterLevel: (json['hunter_level'] as num).toInt(),
      prestige: (json['prestige'] as num).toInt(),
      playHours: (json['play_hours'] as num).toDouble(),
      acs: (json['acs'] as num).toDouble(),
      signatureWeapon: json['signature_weapon'] as String,
      kda: (json['kda'] as num).toDouble(),
      winRate: (json['win_rate'] as num).toDouble(),
      headshotRate: (json['headshot_rate'] as num).toDouble(),
    );

Map<String, dynamic> _$PlayerProfileToJson(PlayerProfile instance) =>
    <String, dynamic>{
      'nickname': instance.nickname,
      'steam_id': instance.steamId,
      'avatar_url': instance.avatarUrl,
      'mmr_stars': instance.mmrStars,
      'hunter_level': instance.hunterLevel,
      'prestige': instance.prestige,
      'play_hours': instance.playHours,
      'acs': instance.acs,
      'signature_weapon': instance.signatureWeapon,
      'kda': instance.kda,
      'win_rate': instance.winRate,
      'headshot_rate': instance.headshotRate,
    };
