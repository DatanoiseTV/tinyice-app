import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';
import 'add_server_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _loadingServerId;

  Future<void> _loginWithServer(ServerConnection server) async {
    if (server.username == null || server.username!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No credentials saved for this server')),
      );
      return;
    }

    setState(() => _loadingServerId = server.id);

    ref.read(selectedServerIdProvider.notifier).select(server.id);

    await ref
        .read(authStateProvider.notifier)
        .login(server.username!, server.password ?? '');

    setState(() => _loadingServerId = null);
  }

  void _navigateToAddServer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddServerScreen()),
    );
  }

  void _navigateToEditServer(ServerConnection server) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddServerScreen(editServer: server)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(serversProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://raw.githubusercontent.com/DatanoiseTV/tinyice/main/assets/logo.png?v=2',
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.radio,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Alpha Client',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (servers.isEmpty) ...[
                const Center(
                  child: Text(
                    'No servers configured',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _navigateToAddServer,
                    child: const Text('Add Server'),
                  ),
                ),
              ] else ...[
                const Text(
                  'Select Server',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                ...servers.map(
                  (server) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ServerCard(
                      server: server,
                      isLoading: _loadingServerId == server.id,
                      onTap: () => _loginWithServer(server),
                      onEdit: () => _navigateToEditServer(server),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _navigateToAddServer,
                  child: const Text('Add New Server'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final ServerConnection server;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ServerCard({
    required this.server,
    required this.isLoading,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasCredentials =
        server.username != null && server.username!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.dns,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    server.url,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              color: AppColors.textMuted,
              onPressed: onEdit,
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else if (!hasCredentials)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'No creds',
                  style: TextStyle(fontSize: 10, color: AppColors.warning),
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textMuted,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
