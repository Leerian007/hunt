import '../models/match_record.dart';
import '../models/player_profile.dart';

/// Deterministic local data for developing the responsive history screens.
class MockHunterService {
  const MockHunterService();

  PlayerProfile get profile => _profile;

  List<MatchRecord> get matchHistory => List.unmodifiable(_matchHistory);

  static const _profile = PlayerProfile(
    nickname: 'Nightwatcher',
    steamId: '76561198012345678',
    avatarUrl: 'https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/00/0000000000000000000000000000000000000000_full.jpg',
    mmrStars: 5,
    hunterLevel: 50,
    prestige: 12,
    playHours: 1842.5,
    acs: 287.4,
    signatureWeapon: 'Mosin-Nagant M1891 Avtomat',
    kda: 2.84,
    winRate: 0.64,
    headshotRate: 0.38,
  );

  static final _matchHistory = [
    MatchRecord(
      matchId: 'm_982341',
      matchTime: DateTime.utc(2026, 10, 8, 15, 30),
      mapName: "Mammon's Gulch",
      extracted: true,
      kills: 3,
      deaths: 0,
      assists: 1,
      teamWipes: 1,
      bountyExtracted: 1250,
      mmr: 2865,
      mmrStars: 5,
      mmrChange: 18,
    ),
    MatchRecord(
      matchId: 'm_982340',
      matchTime: DateTime.utc(2026, 10, 8, 14, 5),
      mapName: 'Stillwater Bayou',
      extracted: false,
      kills: 1,
      deaths: 1,
      assists: 2,
      teamWipes: 0,
      bountyExtracted: 0,
      mmr: 2847,
      mmrStars: 5,
      mmrChange: -12,
    ),
    MatchRecord(
      matchId: 'm_982339',
      matchTime: DateTime.utc(2026, 10, 8, 12, 40),
      mapName: 'Lawson Delta',
      extracted: true,
      kills: 5,
      deaths: 0,
      assists: 0,
      teamWipes: 2,
      bountyExtracted: 2000,
      mmr: 2859,
      mmrStars: 5,
      mmrChange: 22,
    ),
    MatchRecord(
      matchId: 'm_982338',
      matchTime: DateTime.utc(2026, 10, 8, 11, 15),
      mapName: 'DeSalle',
      extracted: false,
      kills: 2,
      deaths: 1,
      assists: 1,
      teamWipes: 0,
      bountyExtracted: 0,
      mmr: 2837,
      mmrStars: 5,
      mmrChange: -16,
    ),
    MatchRecord(
      matchId: 'm_982337',
      matchTime: DateTime.utc(2026, 10, 8, 9, 50),
      mapName: "Mammon's Gulch",
      extracted: true,
      kills: 4,
      deaths: 0,
      assists: 3,
      teamWipes: 1,
      bountyExtracted: 1500,
      mmr: 2853,
      mmrStars: 5,
      mmrChange: 20,
    ),
  ];
}
