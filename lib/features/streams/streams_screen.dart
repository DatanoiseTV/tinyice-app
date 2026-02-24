import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';

final streamsProvider = FutureProvider<List<StreamInfo>>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return [];
  final stats = await client.getStats();
  return stats.streams;
});

class StreamsScreen extends ConsumerStatefulWidget {
  const StreamsScreen({super.key});

  @override
  ConsumerState<StreamsScreen> createState() => _StreamsScreenState();
}

class _StreamsScreenState extends ConsumerState<StreamsScreen> {
  final _mountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _mountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addMount() async {
    if (_mountController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final client = ref.read(apiClientProvider);
    final success = await client?.addMount(
      _mountController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success == true) {
      _mountController.clear();
      _passwordController.clear();
      ref.invalidate(streamsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mount added')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add mount')));
      }
    }
  }

  Future<void> _toggleMount(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleMount(mount);
    ref.invalidate(streamsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == true ? 'Mount toggled' : 'Action failed'),
        ),
      );
    }
  }

  Future<void> _kickStream(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.kickStream(mount);
    ref.invalidate(streamsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == true ? 'Source kicked' : 'Action failed'),
        ),
      );
    }
  }

  Future<void> _toggleVisible(String mount) async {
    final client = ref.read(apiClientProvider);
    await client?.toggleMountVisible(mount);
    ref.invalidate(streamsProvider);
  }

  Future<void> _kickAllListeners(String mount) async {
    final client = ref.read(apiClientProvider);
    await client?.kickAllListeners(mount);
    ref.invalidate(streamsProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All listeners kicked')));
    }
  }

  void _showEditStreamDialog(BuildContext context, StreamInfo stream) {
    final nameController = TextEditingController(text: stream.name);
    final fallbackController = TextEditingController();

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
                Text(
                  'Edit: ${stream.mount}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fallbackController,
                  decoration: const InputDecoration(labelText: 'Fallback URL'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final client = ref.read(apiClientProvider);
                      final success = await client?.updateMount(
                        mount: stream.mount,
                        fallback: fallbackController.text.isEmpty
                            ? null
                            : fallbackController.text,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.invalidate(streamsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success == true
                                  ? 'Mount updated'
                                  : 'Failed to update mount',
                            ),
                          ),
                        );
                      }
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

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(serverStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Streams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMountDialog(context),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (stats) {
          if (stats.streams.isEmpty) {
            return const EmptyState(
              icon: Icons.radio_button_off,
              title: 'No Active Streams',
            );
          }

          final sortedStreams = List<StreamInfo>.from(stats.streams)
            ..sort((a, b) {
              if (a.listeners > 0 && b.listeners == 0) return -1;
              if (b.listeners > 0 && a.listeners == 0) return 1;
              return a.name.compareTo(b.name);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedStreams.length,
            itemBuilder: (context, index) {
              final stream = sortedStreams[index];
              return _StreamTile(
                stream: stream,
                onKick: () => _kickStream(stream.mount),
                onToggle: () => _toggleMount(stream.mount),
                onEdit: () => _showEditStreamDialog(context, stream),
                onToggleVisible: () => _toggleVisible(stream.mount),
                onKickAll: () => _kickAllListeners(stream.mount),
              );
            },
          );
        },
      ),
    );
  }

  void _showStreamOptions(BuildContext context, StreamInfo stream) {
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
            ListTile(
              leading: const Icon(Icons.eject, color: AppColors.error),
              title: const Text('Kick Source'),
              onTap: () {
                Navigator.pop(context);
                _kickStream(stream.mount);
              },
            ),
            ListTile(
              leading: const Icon(Icons.toggle_on, color: AppColors.warning),
              title: const Text('Toggle Mount'),
              onTap: () {
                Navigator.pop(context);
                _toggleMount(stream.mount);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddMountDialog(BuildContext context) {
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
                  'Add Mount Point',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _mountController,
                  decoration: const InputDecoration(
                    labelText: 'Mount Point',
                    hintText: '/my-stream',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addMount,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Mount'),
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

class _StreamTile extends StatelessWidget {
  final StreamInfo stream;
  final VoidCallback onKick;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onToggleVisible;
  final VoidCallback onKickAll;

  const _StreamTile({
    required this.stream,
    required this.onKick,
    required this.onToggle,
    required this.onEdit,
    required this.onToggleVisible,
    required this.onKickAll,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = stream.listeners > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              color: isLive ? AppColors.success : AppColors.offline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              stream.name.isNotEmpty ? stream.name : stream.mount,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            stream.bitrate,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLive
                  ? AppColors.success.withAlpha(25)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.headphones,
                  size: 12,
                  color: isLive ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  stream.listeners.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLive ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'kick') onKick();
              if (value == 'toggle') onToggle();
              if (value == 'edit') onEdit();
              if (value == 'visible') onToggleVisible();
              if (value == 'kickall') onKickAll();
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
                value: 'visible',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 18),
                    SizedBox(width: 8),
                    Text('Toggle Visible'),
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
                value: 'kickall',
                child: Row(
                  children: [
                    Icon(Icons.eject, size: 18),
                    SizedBox(width: 8),
                    Text('Kick All Listeners'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'kick',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Kick Source',
                      style: TextStyle(color: AppColors.error),
                    ),
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
