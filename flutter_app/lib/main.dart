import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chat/room_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TeamApp()));
}

class TeamApp extends ConsumerWidget {
  const TeamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Team App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A6B5C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // replaced by platform default; swap for brand font later
      ),
      home: auth.when(
        data: (state) =>
            state.isAuthenticated ? const RoomListScreen() : const LoginScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}
