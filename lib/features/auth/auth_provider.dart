import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../services/auth_service.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

export 'auth_controller.dart';
export 'auth_state.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(client: ref.watch(apiClientProvider)),
);
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);

// Watched by the startup gate, so the initial page cannot flash guest content
// while a persisted session or a cold-start callback is being verified.
final authBootstrapProvider = FutureProvider<void>(
  (ref) => ref.read(authProvider.notifier).initialize(),
);
