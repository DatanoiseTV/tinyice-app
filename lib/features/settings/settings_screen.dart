import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';
import 'security_screen.dart';
import '../webhooks/webhooks_screen.dart';
import '../users/users_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(selectedServerProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Connection'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.dns,
                  title: 'Server',
                  subtitle: server?.url ?? 'Not connected',
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.person,
                  title: 'Logged in as',
                  subtitle: user?.username ?? 'Unknown',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Management'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.block,
                  title: 'Security',
                  subtitle: 'IP bans, whitelist, lockouts',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityScreen()),
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.people,
                  title: 'Users',
                  subtitle: 'Manage admin users',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersScreen()),
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.webhook,
                  title: 'Webhooks',
                  subtitle: 'Manage webhooks',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebhooksScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('About'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.info,
                  title: 'TinyIce Client',
                  subtitle: 'Version 1.0.0',
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.code,
                  title: 'Built with',
                  subtitle: 'Flutter',
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.link,
                  title: 'GitHub',
                  subtitle: 'github.com/DatanoiseTV/tinyice',
                  onTap: () {
                    // Could open URL here
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showIpDialog(BuildContext context, WidgetRef ref) {
    final ipController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IP Banning',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter an IP or CIDR to ban',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.0/24',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (ipController.text.isNotEmpty) {
                        final client = ref.read(apiClientProvider);
                        await client?.banIp(ipController.text);
                        ipController.clear();
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('IP banned')),
                          );
                      }
                    },
                    child: const Text('Ban IP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
