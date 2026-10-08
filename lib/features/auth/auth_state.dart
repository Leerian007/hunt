import '../../services/player_service.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.token,
    this.steamId,
    this.userProfile,
    this.error,
  });
  final AuthStatus status;
  final String? token;
  final String? steamId;
  final SteamPlayer? userProfile;
  final String? error;
}
