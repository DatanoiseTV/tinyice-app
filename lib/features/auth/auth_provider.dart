import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models/models.dart';
import '../../shared/providers/server_providers.dart';

final _authenticatedClientsProvider =
    StateProvider<Map<String, TinyIceApiClient>>((ref) => {});

final apiClientProvider = Provider<TinyIceApiClient?>((ref) {
  final server = ref.watch(selectedServerProvider);
  if (server == null) return null;

  final authClients = ref.watch(_authenticatedClientsProvider);
  final authClient = authClients[server.url];

  if (authClient != null) {
    return authClient;
  }

  return TinyIceApiClient(baseUrl: server.url);
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final client = ref.watch(apiClientProvider);
    if (client == null) {
      return AuthState.unauthenticated();
    }
    if (client.isAuthenticated) {
      return AuthState.authenticated(
        client.currentUser ?? User(username: 'admin', role: 'admin'),
        client.csrfToken ?? '',
      );
    }
    return AuthState.unauthenticated();
  }

  Future<void> login(String username, String password) async {
    final server = ref.read(selectedServerProvider);
    debugPrint('TinyIce: Login attempt to ${server?.url}');

    if (server == null) {
      state = AuthState.error('No server selected');
      return;
    }

    state = AuthState(isAuthenticated: false, user: null, error: null);

    // Create a new client for this server
    final client = TinyIceApiClient(baseUrl: server.url);
    final result = await client.login(username, password);

    debugPrint(
      'TinyIce: Login result - ${result.isAuthenticated ? "success" : "failed: ${result.error}"}',
    );

    if (result.isAuthenticated) {
      // Store the authenticated client for this server URL
      final clients = Map<String, TinyIceApiClient>.from(
        ref.read(_authenticatedClientsProvider),
      );
      clients[server.url] = client;
      ref.read(_authenticatedClientsProvider.notifier).state = clients;
      state = AuthState.authenticated(result.user!, result.csrfToken ?? '');
      debugPrint('TinyIce: Auth state updated to authenticated');
    } else {
      state = AuthState.error(result.error ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    final server = ref.read(selectedServerProvider);
    final clients = Map<String, TinyIceApiClient>.from(
      ref.read(_authenticatedClientsProvider),
    );
    final client = server != null ? clients.remove(server.url) : null;
    await client?.logout();
    ref.read(_authenticatedClientsProvider.notifier).state = clients;
    state = AuthState.unauthenticated();
  }

  void clearError() {
    if (!state.isAuthenticated) {
      state = AuthState.unauthenticated();
    }
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.user;
});
