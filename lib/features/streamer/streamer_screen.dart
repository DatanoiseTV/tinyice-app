import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';

class StreamerScreen extends ConsumerStatefulWidget {
  const StreamerScreen({super.key});

  @override
  ConsumerState<StreamerScreen> createState() => _StreamerScreenState();
}

class _StreamerScreenState extends ConsumerState<StreamerScreen> {
  String? _selectedMount;

  Future<void> _togglePlayPause(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'toggle');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success == true ? 'Toggled' : 'Action failed')),
      );
    }
  }

  Future<void> _nextTrack(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'next');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success == true ? 'Skipped' : 'Action failed')),
      );
    }
  }

  Future<void> _prevTrack(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'prev');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success == true ? 'Previous' : 'Action failed')),
      );
    }
  }

  Future<void> _toggleShuffle(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'shuffle');
    ref.invalidate(serverStatsProvider);
  }

  Future<void> _toggleLoop(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'loop');
    ref.invalidate(serverStatsProvider);
  }

  Future<void> _restart(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'restart');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == true ? 'Restarted' : 'Action failed'),
        ),
      );
    }
  }

  Future<void> _scan(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'scan');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == true ? 'Scanning...' : 'Action failed'),
        ),
      );
    }
  }

  Future<void> _clearQueue(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'clear_queue');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == true ? 'Queue cleared' : 'Action failed'),
        ),
      );
    }
  }

  Future<void> _savePlaylist(String mount) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.toggleStreamer(mount, 'save_playlist');
    ref.invalidate(serverStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == true ? 'Playlist saved' : 'Action failed'),
        ),
      );
    }
  }

  void _showEditAutoDJDialog(
    BuildContext context,
    List<StreamerInfo> streamers,
  ) {
    if (streamers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit AutoDJ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...streamers.map(
                (s) => ListTile(
                  leading: const Icon(Icons.radio),
                  title: Text(s.name.isNotEmpty ? s.name : s.mount),
                  subtitle: Text(s.mount),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditSingleAutoDJDialog(context, s);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSingleAutoDJDialog(
    BuildContext context,
    StreamerInfo streamer,
  ) {
    final nameController = TextEditingController(text: streamer.name);
    final mountController = TextEditingController(text: streamer.mount);

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
                  'Edit: ${streamer.mount}',
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
                  controller: mountController,
                  decoration: const InputDecoration(labelText: 'Mount Point'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Note: Backend would need update endpoint
                      // For now just show a message
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AutoDJ update not implemented in API'),
                        ),
                      );
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
        title: const Text('AutoDJ'),
        actions: [
          if (statsAsync.value != null &&
              statsAsync.value!.streamers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  _showEditAutoDJDialog(context, statsAsync.value!.streamers),
            ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (stats) {
          if (stats.streamers.isEmpty) {
            return const EmptyState(
              icon: Icons.play_circle_outline,
              title: 'No AutoDJ Configured',
            );
          }

          _selectedMount ??= stats.streamers.first.mount;

          final streamer = stats.streamers.firstWhere(
            (s) => s.mount == _selectedMount,
            orElse: () => stats.streamers.first,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stats.streamers.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedMount,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.surface,
                      items: stats.streamers.toSet().map((s) {
                        return DropdownMenuItem(
                          value: s.mount,
                          child: Text(s.name.isNotEmpty ? s.name : s.mount),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedMount = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Now playing card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        streamer.currentSong.isNotEmpty
                            ? streamer.currentSong
                            : 'No track playing',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${streamer.playlistPos + 1} / ${streamer.playlistLen}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlBtn(
                            icon: Icons.shuffle,
                            isActive: streamer.shuffle,
                            onTap: () => _toggleShuffle(streamer.mount),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _togglePlayPause(streamer.mount),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                streamer.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _ControlBtn(
                            icon: Icons.skip_next,
                            onTap: () => _nextTrack(streamer.mount),
                          ),
                          const SizedBox(width: 16),
                          _ControlBtn(
                            icon: Icons.repeat,
                            isActive: streamer.loop,
                            onTap: () => _toggleLoop(streamer.mount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick actions row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionBtn(
                        icon: Icons.refresh,
                        label: 'Scan',
                        onTap: () => _scan(streamer.mount),
                      ),
                      _ActionBtn(
                        icon: Icons.playlist_add,
                        label: 'Save',
                        onTap: () => _savePlaylist(streamer.mount),
                      ),
                      _ActionBtn(
                        icon: Icons.queue_music,
                        label: 'Clear Q',
                        onTap: () => _clearQueue(streamer.mount),
                      ),
                      _ActionBtn(
                        icon: Icons.restart_alt,
                        label: 'Restart',
                        onTap: () => _restart(streamer.mount),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (streamer.queue.isNotEmpty) ...[
                  const SectionTitle('Up Next'),
                  ...streamer.queue
                      .take(5)
                      .map((item) => _QueueItem(item: item)),
                  const SizedBox(height: 16),
                ],
                if (streamer.playlist.isNotEmpty) ...[
                  const SectionTitle('Playlist'),
                  ...streamer.playlist
                      .skip(streamer.playlistPos)
                      .take(10)
                      .map((item) => _PlaylistItem(item: item)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final PlaylistItem item;
  const _QueueItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue_music, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title.isNotEmpty ? item.title : item.path.split('/').last,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  final PlaylistItem item;
  const _PlaylistItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title.isNotEmpty ? item.title : item.path.split('/').last,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
