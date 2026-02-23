import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';

final securityStatsProvider = FutureProvider<SecurityStats?>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return client.getSecurityStats();
});

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Security')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final client = ref.read(apiClientProvider);
                      await client?.clearAuthLockout();
                      ref.invalidate(securityStatsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auth lockout cleared')),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Clear Auth Lockout'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final client = ref.read(apiClientProvider);
                      await client?.clearScanLockout();
                      ref.invalidate(securityStatsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scan lockout cleared')),
                        );
                      }
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Clear Scan Lockout'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ref
                .watch(securityStatsProvider)
                .when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (stats) {
                    if (stats == null) {
                      return const EmptyState(
                        icon: Icons.shield,
                        title: 'No Security Data',
                      );
                    }
                    return _SecurityContent(stats: stats);
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _SecurityContent extends ConsumerStatefulWidget {
  final SecurityStats stats;

  const _SecurityContent({required this.stats});

  @override
  ConsumerState<_SecurityContent> createState() => _SecurityContentState();
}

class _SecurityContentState extends ConsumerState<_SecurityContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ipController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _banIp() async {
    if (_ipController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final client = ref.read(apiClientProvider);
    await client?.banIp(_ipController.text);
    _ipController.clear();
    ref.invalidate(securityStatsProvider);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('IP banned')));
    }
  }

  Future<void> _unbanIp(String ip) async {
    setState(() => _isLoading = true);
    final client = ref.read(apiClientProvider);
    await client?.unbanIp(ip);
    ref.invalidate(securityStatsProvider);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$ip unbanned')));
    }
  }

  Future<void> _whitelistIp(String ip) async {
    setState(() => _isLoading = true);
    final client = ref.read(apiClientProvider);
    await client?.whitelistIp(ip);
    _ipController.clear();
    ref.invalidate(securityStatsProvider);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('IP whitelisted')));
    }
  }

  Future<void> _unwhitelistIp(String ip) async {
    setState(() => _isLoading = true);
    final client = ref.read(apiClientProvider);
    await client?.unwhitelistIp(ip);
    ref.invalidate(securityStatsProvider);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$ip removed from whitelist')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Banned IPs'),
              Tab(text: 'Whitelist'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _IpList(
                title: 'Banned IPs',
                ips: widget.stats.bannedIPs,
                emptyMessage: 'No banned IPs',
                onRemove: _unbanIp,
                isLoading: _isLoading,
              ),
              _IpList(
                title: 'Whitelisted IPs',
                ips: widget.stats.whitelistedIPs,
                emptyMessage: 'No whitelisted IPs',
                onRemove: _unwhitelistIp,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    hintText: 'IP or CIDR (e.g. 192.168.1.0/24)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) {
                  final ip = _ipController.text;
                  if (ip.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter an IP address')),
                    );
                    return;
                  }
                  if (value == 'ban') _banIp();
                  if (value == 'whitelist') _whitelistIp(ip);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'ban',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text('Ban IP'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'whitelist',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Whitelist IP'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IpList extends StatelessWidget {
  final String title;
  final List<String> ips;
  final String emptyMessage;
  final Future<void> Function(String) onRemove;
  final bool isLoading;

  const _IpList({
    required this.title,
    required this.ips,
    required this.emptyMessage,
    required this.onRemove,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (ips.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ips.length,
      itemBuilder: (context, index) {
        final ip = ips[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.dns, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(child: Text(ip)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error,
                onPressed: isLoading ? null : () => onRemove(ip),
              ),
            ],
          ),
        );
      },
    );
  }
}
