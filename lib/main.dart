import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/main_screen.dart';
import 'shared/providers/server_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TinyIceApp(),
    ),
  );
}

class TinyIceApp extends ConsumerWidget {
  const TinyIceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TinyIce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final hasServers = ref.watch(serversProvider).isNotEmpty;
    final selectedServer = ref.watch(selectedServerProvider);

    // If no servers configured, show login
    if (!hasServers) {
      return const LoginScreen();
    }

    // If server selected but not authenticated, show login
    if (selectedServer != null && !isAuthenticated) {
      return const LoginScreen();
    }

    // If authenticated, show main screen
    if (isAuthenticated) {
      return const MainScreen();
    }

    return const LoginScreen();
  }
}
