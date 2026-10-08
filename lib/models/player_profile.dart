import 'package:json_annotation/json_annotation.dart';

part 'player_profile.g.dart';

/// A player's career summary as reported by the sync service.
@JsonSerializable()
class PlayerProfile {
  const PlayerProfile({
    required this.nickname,
    required this.steamId,
    required this.avatarUrl,
    required this.mmrStars,
    required this.hunterLevel,
    required this.prestige,
    required this.playHours,
    required this.acs,
    required this.signatureWeapon,
    required this.kda,
    required this.winRate,
    required this.headshotRate,
    this.personaState = 0,
    this.totalKills,
    this.totalExtractions,
    this.totalBounty,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) =>
      _$PlayerProfileFromJson(json);

  final String nickname;
  @JsonKey(name: 'steam_id')
  final String steamId;
  @JsonKey(name: 'avatar_url')
  final String avatarUrl;
  @JsonKey(name: 'mmr_stars')
  final int? mmrStars;
  @JsonKey(name: 'hunter_level')
  final int? hunterLevel;
  final int? prestige;
  @JsonKey(name: 'play_hours')
  final double? playHours;
  final double? acs;
  @JsonKey(name: 'signature_weapon')
  final String? signatureWeapon;
  @JsonKey(name: 'kda')
  final double? kda;
  @JsonKey(name: 'win_rate')
  /// Career extraction rate, expressed as a fraction from 0 to 1.
  final double? winRate;
  @JsonKey(name: 'headshot_rate')
  /// Headshot rate, expressed as a fraction from 0 to 1.
  final double? headshotRate;

  @JsonKey(name: 'persona_state', defaultValue: 0)
  final int personaState;
  @JsonKey(name: 'total_kills')
  final int? totalKills;
  @JsonKey(name: 'total_extractions')
  final int? totalExtractions;
  @JsonKey(name: 'total_bounty')
  final int? totalBounty;

  /// Steam only supplies identity/status; Hunt statistics remain unchanged.
  PlayerProfile withSteamIdentity({
    required String steamId,
    required String nickname,
    required String avatarUrl,
    required int personaState,
  }) => PlayerProfile(
    nickname: nickname,
    steamId: steamId,
    avatarUrl: avatarUrl,
    personaState: personaState,
    totalKills: totalKills,
    totalExtractions: totalExtractions,
    totalBounty: totalBounty,
    mmrStars: mmrStars,
    hunterLevel: hunterLevel,
    prestige: prestige,
    playHours: playHours,
    acs: acs,
    signatureWeapon: signatureWeapon,
    kda: kda,
    winRate: winRate,
    headshotRate: headshotRate,
  );

  Map<String, dynamic> toJson() => _$PlayerProfileToJson(this);
}
