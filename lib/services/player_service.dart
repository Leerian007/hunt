import '../core/network/api_client.dart';
import '../models/player_profile.dart';

class SteamPlayer {
  const SteamPlayer({
    required this.steamId,
    required this.personaName,
    required this.avatarFull,
  });
  final String steamId;
  final String personaName;
  final String avatarFull;

  PlayerProfile mergeInto(PlayerProfile profile) => profile.withSteamIdentity(
    steamId: steamId,
    nickname: personaName,
    avatarUrl: avatarFull,
    personaState: profile.personaState,
  );
}

class PlayerService {
  PlayerService({ApiClient? client}) : client = client ?? ApiClient.instance;
  final ApiClient client;

  Future<SteamPlayer> fetchPlayerSummary(String steamId) async {
    if (!RegExp(r'^\d{17}$').hasMatch(steamId)) {
      throw const FormatException('Invalid SteamID64');
    }
    final data = await client.get('/players/$steamId/summary');
    if (data['steam_id'] != steamId ||
        data['persona_name'] is! String ||
        data['avatar_full'] is! String ||
        Uri.tryParse(data['avatar_full'] as String)?.scheme != 'https') {
      throw const FormatException('Invalid player summary');
    }
    return SteamPlayer(
      steamId: steamId,
      personaName: data['persona_name'] as String,
      avatarFull: data['avatar_full'] as String,
    );
  }
}
