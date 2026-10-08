import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/match_record.dart';
import '../models/player_profile.dart';
import '../models/match_filter.dart';
import 'player_service.dart';

class PlayerStats {
  const PlayerStats(this.data);
  final Map<String, dynamic> data;

  PlayerProfile merge(SteamPlayer summary) => PlayerProfile.fromJson({
    ...data,
    'total_extractions': data['extracted_matches'],
    'total_bounty': data['total_bounty_extracted'],
    'win_rate': data['extraction_rate'] ?? data['win_rate'],
    'nickname': summary.personaName,
    'steam_id': summary.steamId,
    'avatar_url': summary.avatarFull,
  });
}

class MatchPage {
  const MatchPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });
  final List<MatchRecord> items;
  final int page;
  final bool hasMore;
}

class HunterApiService {
  HunterApiService({ApiClient? client}) : client = client ?? ApiClient.instance;
  final ApiClient client;

  Future<SteamPlayer> fetchPlayerSummary(String steamId) =>
      PlayerService(client: client).fetchPlayerSummary(steamId);

  Future<PlayerStats> fetchPlayerStats(String steamId) async {
    _validateId(steamId);
    final data = await client.get('/players/$steamId/stats');
    if (data['steam_id'] != null && data['steam_id'] != steamId) {
      throw const FormatException('Stats account mismatch');
    }
    return PlayerStats(data);
  }

  Future<MatchPage> fetchMatchHistory(
    String steamId, {
    required int page,
    int size = 20,
    MatchFilter filter = MatchFilter.all,
  }) async {
    _validateId(steamId);
    if (page < 1 || size < 1) throw ArgumentError('Invalid pagination');
    final data = await client.get(
      '/players/$steamId/matches',
      query: {'page': page, 'size': size, 'filter': filter.name},
    );
    final rows = data['list'];
    final total = data['total'];
    final pages = data['pages'];
    if (rows is! List ||
        total is! int ||
        total < 0 ||
        pages is! int ||
        pages < 0) {
      throw const FormatException('Invalid match pagination response');
    }
    final items = rows
        .map(
          (row) => MatchRecord.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    return MatchPage(
      items: List.unmodifiable(items),
      page: page,
      hasMore: rows.isNotEmpty && page < pages,
    );
  }

  void _validateId(String id) {
    if (!RegExp(r'^\d{17}$').hasMatch(id)) {
      throw const FormatException('Invalid SteamID64');
    }
  }
}

final hunterApiServiceProvider = Provider<HunterApiService>(
  (ref) => HunterApiService(client: ref.watch(apiClientProvider)),
);
