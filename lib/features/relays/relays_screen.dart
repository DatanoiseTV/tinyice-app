import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_screen.dart' show serverStatsProvider;

final relaysProvider = Provider<AsyncValue<List<RelayInfo>>>((ref) {
  final statsAsync = ref.watch(serverStatsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.relays),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

class RelaysScreen extends ConsumerStatefulWidget {
  const RelaysScreen({super.key});

  @override
  ConsumerState<RelaysScreen> createState() => _RelaysScreenState();
}

class _RelaysScreenState extends ConsumerState<RelaysScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Relays'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRelayDialog(context),
          ),
        ],
      ),
      body: ref
          .watch(relaysProvider)
          .when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (relays) {
              if (relays.isEmpty) {
                return const EmptyState(icon: Icons.repeat, title: 'No Relays');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: relays.length,
                itemBuilder: (context, index) {
                  final relay = relays[index];
                  return _RelayTile(
                    relay: relay,
                    onEdit: (relay) => _showEditRelayDialog(context, relay),
                  );
                },
              );
            },
          ),
    );
  }

  void _showAddRelayDialog(BuildContext context) {
    final sourceController = TextEditingController();
    final mountController = TextEditingController();
    final passwordController = TextEditingController();
    final burstController = TextEditingController(text: '20');

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
                  'Add Relay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Source URL',
                    hintText: 'https://radio.example.com/stream',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mountController,
                  decoration: const InputDecoration(
                    labelText: 'Mount Point',
                    hintText: '/relay',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (optional)',
                    hintText: 'Source password if required',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: burstController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Burst Size',
                    hintText: '20',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (sourceController.text.isEmpty ||
                          mountController.text.isEmpty) {
                        return;
                      }
                      final client = ref.read(apiClientProvider);
                      await client?.addRelay(
                        sourceController.text,
                        mountController.text,
                      );
                      ref.invalidate(relaysProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Add Relay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditRelayDialog(BuildContext context, RelayInfo relay) {
    final sourceController = TextEditingController(text: relay.url);
    final mountController = TextEditingController(text: relay.mount);

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
                  'Edit Relay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Source URL',
                    hintText: 'https://radio.example.com/stream',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mountController,
                  decoration: const InputDecoration(
                    labelText: 'Mount Point',
                    hintText: '/relay',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (sourceController.text.isEmpty ||
                          mountController.text.isEmpty) {
                        return;
                      }
                      // Delete old relay and add new one (relay update)
                      final client = ref.read(apiClientProvider);
                      await client?.deleteRelay(relay.mount);
                      await client?.addRelay(
                        sourceController.text,
                        mountController.text,
                      );
                      ref.invalidate(relaysProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save Changes'),
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

class _RelayTile extends ConsumerWidget {
  final RelayInfo relay;
  final Function(RelayInfo) onEdit;

  const _RelayTile({required this.relay, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: relay.active ? AppColors.success : AppColors.offline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relay.mount,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  relay.url,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: relay.active
                  ? AppColors.success.withAlpha(25)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              relay.active ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: relay.active ? AppColors.success : AppColors.textMuted,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            color: AppColors.surface,
            onSelected: (value) async {
              final client = ref.read(apiClientProvider);
              if (value == 'toggle') {
                await client?.toggleRelay(relay.mount);
                ref.invalidate(relaysProvider);
              } else if (value == 'restart') {
                await client?.restartRelay(relay.mount);
                ref.invalidate(relaysProvider);
              } else if (value == 'edit') {
                onEdit(relay);
              } else if (value == 'delete') {
                await client?.deleteRelay(relay.mount);
                ref.invalidate(relaysProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(Icons.toggle_on, size: 18),
                    SizedBox(width: 8),
                    Text('Toggle'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restart',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Restart'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
