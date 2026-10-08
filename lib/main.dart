import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/profile/hunter_profile_page.dart';
import 'features/auth/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hunt 1896 · 猎人档案',
    debugShowCheckedModeBanner: false,
    // Auth callbacks are handled by AuthNotifier, not by Navigator routes.
    initialRoute: '/',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.grey[900],
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD5BC86),
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: const Color(0xFFF6F3EA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    ),
    home: const _SessionGate(),
  );
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(authBootstrapProvider);
    if (!startup.isLoading) return const HunterProfilePage();
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HUNT 1896',
                  style: TextStyle(
                    color: Color(0xFFD5BC86),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    color: Color(0xFFD5BC86),
                    backgroundColor: Color(0xFF233039),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '正在恢复 Steam 会话…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFADBAC1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
