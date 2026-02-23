import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';

final serverStatsProvider = StreamProvider<ServerStats>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return Stream.value(ServerStats.empty());

  return Stream.fromFuture(client.getStats()).asyncExpand((initialStats) {
    return client.subscribeToStats();
  });
});

final listenerHistoryProvider = StateProvider<List<int>>((ref) => []);

enum StreamSortField { listeners, name, bitrate }

final streamSortFieldProvider = StateProvider<StreamSortField>(
  (ref) => StreamSortField.listeners,
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(serverStatsProvider);

    ref.listen(serverStatsProvider, (previous, next) {
      next.whenData((stats) {
        final history = ref.read(listenerHistoryProvider);
        final newHistory = [...history, stats.totalListeners];
        if (newHistory.length > 30) {
          newHistory.removeAt(0);
        }
        ref.read(listenerHistoryProvider.notifier).state = newHistory;
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(serverStatsProvider),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'switch') {
                _showServerSwitcher(context);
              } else if (value == 'logout') {
                ref.read(authStateProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 12),
                    Text('Switch Server'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const LoadingView(message: 'Connecting...'),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(serverStatsProvider),
        ),
        data: (stats) => _buildContent(stats),
      ),
    );
  }

  Widget _buildContent(ServerStats stats) {
    final history = ref.watch(listenerHistoryProvider);
    final sortField = ref.watch(streamSortFieldProvider);

    String formatUptime(String uptime) {
      final regex = RegExp(r'(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?');
      final match = regex.firstMatch(uptime);
      if (match == null) return uptime;
      final h = match.group(1);
      final m = match.group(2);
      if (h != null) return '${h}h';
      if (m != null) return '${m}m';
      return match.group(3) ?? uptime;
    }

    final sortedStreams = List<StreamInfo>.from(stats.streams)
      ..sort((a, b) {
        switch (sortField) {
          case StreamSortField.listeners:
            if (a.listeners != b.listeners)
              return b.listeners.compareTo(a.listeners);
            return a.name.compareTo(b.name);
          case StreamSortField.name:
            return a.name.compareTo(b.name);
          case StreamSortField.bitrate:
            return b.bitrate.compareTo(a.bitrate);
        }
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _CompactStat(
                value: stats.totalListeners.toString(),
                label: 'Listeners',
                color: AppColors.primary,
              ),
              _CompactStat(
                value: stats.streams.length.toString(),
                label: 'Streams',
                color: AppColors.success,
              ),
              _CompactStat(
                value: stats.streamers.length.toString(),
                label: 'AutoDJs',
                color: AppColors.warning,
              ),
              _CompactStat(
                value: formatUptime(stats.serverUptime),
                label: 'Uptime',
                color: AppColors.info,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          height: 80,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text(
                'Listeners',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: ListenerChart(data: history)),
              Expanded(
                flex: 1,
                child: _TrafficIndicator(
                  bytesIn: stats.bytesIn,
                  bytesOut: stats.bytesOut,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Streams',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            PopupMenuButton<StreamSortField>(
              initialValue: sortField,
              icon: const Icon(
                Icons.sort,
                size: 18,
                color: AppColors.textMuted,
              ),
              color: AppColors.surface,
              onSelected: (value) {
                ref.read(streamSortFieldProvider.notifier).state = value;
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: StreamSortField.listeners,
                  child: Text('Listeners'),
                ),
                const PopupMenuItem(
                  value: StreamSortField.name,
                  child: Text('Name'),
                ),
                const PopupMenuItem(
                  value: StreamSortField.bitrate,
                  child: Text('Bitrate'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sortedStreams.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No active streams',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedStreams.length,
            itemBuilder: (context, index) {
              final stream = sortedStreams[index];
              return _StreamTile(stream: stream);
            },
          ),

        const SizedBox(height: 100),
      ],
    );
  }

  void _showServerSwitcher(BuildContext context) {
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
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('Add New Server'),
              onTap: () {
                Navigator.pop(context);
                ref.read(authStateProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _CompactStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TrafficIndicator extends StatelessWidget {
  final int bytesIn;
  final int bytesOut;

  const _TrafficIndicator({required this.bytesIn, required this.bytesOut});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}G';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward, size: 12, color: AppColors.success),
            const SizedBox(width: 2),
            Text(
              _formatBytes(bytesOut),
              style: const TextStyle(fontSize: 10, color: AppColors.success),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward, size: 12, color: AppColors.error),
            const SizedBox(width: 2),
            Text(
              _formatBytes(bytesIn),
              style: const TextStyle(fontSize: 10, color: AppColors.error),
            ),
          ],
        ),
      ],
    );
  }
}

class _StreamTile extends StatelessWidget {
  final StreamInfo stream;

  const _StreamTile({required this.stream});

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
        ],
      ),
    );
  }
}
