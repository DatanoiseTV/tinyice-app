import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/server_providers.dart';
import 'auth/auth_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'streams/streams_screen.dart';
import 'streamer/streamer_screen.dart';
import 'history/history_screen.dart';
import 'relays/relays_screen.dart';
import 'transcoders/transcoders_screen.dart';
import 'golive/golive_screen.dart';
import 'settings/settings_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final server = ref.watch(selectedServerProvider);

    if (!isAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: server != null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: AppColors.surface,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.dns,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            server.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () => _showServerSwitcher(context, ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Switch',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: IndexedStack(
              index: selectedTab,
              children: const [
                DashboardScreen(),
                StreamsScreen(),
                StreamerScreen(),
                GoLiveScreen(),
                HistoryScreen(),
                RelaysScreen(),
                TranscodersScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.surfaceLight, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isSelected: selectedTab == 0,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.radio,
                  label: 'Streams',
                  isSelected: selectedTab == 1,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.play_circle,
                  label: 'AutoDJ',
                  isSelected: selectedTab == 2,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 2,
                ),
                _NavItem(
                  icon: Icons.radio_button_checked,
                  label: 'Go Live',
                  isSelected: selectedTab == 3,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 3,
                ),
                _NavItem(
                  icon: Icons.more_horiz,
                  label: 'More',
                  isSelected: selectedTab >= 4,
                  onTap: () => _showMoreMenu(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerSwitcher(BuildContext context, WidgetRef ref) {
    final servers = ref.read(serversProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Switch Server',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...servers.map(
              (s) => ListTile(
                leading: const Icon(Icons.dns),
                title: Text(s.name),
                subtitle: Text(s.url),
                trailing: s.id == ref.read(selectedServerProvider)?.id
                    ? const Icon(Icons.check, color: AppColors.success)
                    : null,
                onTap: () {
                  ref.read(selectedServerIdProvider.notifier).select(s.id);
                  ref.invalidate(serverStatsProvider);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'More',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _MoreMenuItem(
              icon: Icons.history,
              title: 'History',
              subtitle: 'View broadcast history',
              onTap: () {
                Navigator.pop(context);
                ref.read(selectedTabProvider.notifier).state = 4;
              },
            ),
            _MoreMenuItem(
              icon: Icons.repeat,
              title: 'Relays',
              subtitle: 'Manage relay connections',
              onTap: () {
                Navigator.pop(context);
                ref.read(selectedTabProvider.notifier).state = 5;
              },
            ),
            _MoreMenuItem(
              icon: Icons.tune,
              title: 'Transcoders',
              subtitle: 'Manage transcoders',
              onTap: () {
                Navigator.pop(context);
                ref.read(selectedTabProvider.notifier).state = 6;
              },
            ),
            const Divider(height: 32),
            _MoreMenuItem(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App and server settings',
              onTap: () {
                Navigator.pop(context);
                ref.read(selectedTabProvider.notifier).state = 7;
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
