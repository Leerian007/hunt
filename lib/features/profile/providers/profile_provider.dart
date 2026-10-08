import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/player_profile.dart';
import '../../../services/hunter_api_service.dart';
import '../../auth/auth_provider.dart';

final profileProvider = FutureProvider.autoDispose<PlayerProfile?>((ref) async {
  final session = ref.watch(
    authProvider.select((auth) => (auth.status, auth.steamId, auth.token)),
  );
  if (session.$1 != AuthStatus.authenticated || session.$2 == null) return null;
  final service = ref.watch(hunterApiServiceProvider);
  // Start both requests before awaiting either; neither result is a fallback.
  final summary = service.fetchPlayerSummary(session.$2!);
  final stats = service.fetchPlayerStats(session.$2!);
  final results = await Future.wait<Object>([summary, stats]);
  return (results[1] as PlayerStats).merge(await summary);
});
