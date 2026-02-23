import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';

final selectedHistoryMountProvider = StateProvider<String?>((ref) => null);

final showInactiveMountsProvider = StateProvider<bool>((ref) => false);

class MountsWithHistoryNotifier extends Notifier<AsyncValue<Set<String>>> {
  @override
  AsyncValue<Set<String>> build() {
    return const AsyncValue.loading();
  }

  Future<void> loadMountsWithHistory(List<StreamInfo> streams) async {
    if (state.hasValue && state.value!.isNotEmpty) return;

    final client = ref.read(apiClientProvider);
    if (client == null) {
      state = AsyncValue.data({});
      return;
    }

    state = const AsyncValue.loading();

    final mountsWithHistory = <String>{};

    await Future.wait(
      streams.map((stream) async {
        try {
          final history = await client.getHistory(stream.mount);
          if (history.isNotEmpty) {
            mountsWithHistory.add(stream.mount);
          }
        } catch (e) {
          debugPrint('Error fetching history for ${stream.mount}: $e');
        }
      }),
    );

    state = AsyncValue.data(mountsWithHistory);
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final mountsWithHistoryProvider =
    NotifierProvider<MountsWithHistoryNotifier, AsyncValue<Set<String>>>(
      MountsWithHistoryNotifier.new,
    );

final historyProvider = FutureProvider.family<List<HistoryEntry>, String>((
  ref,
  mount,
) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return [];
  return client.getHistory(mount);
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(serverStatsProvider);
    final selectedMount = ref.watch(selectedHistoryMountProvider);
    final showInactive = ref.watch(showInactiveMountsProvider);
    final mountsWithHistoryAsync = ref.watch(mountsWithHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('History')),
      body: statsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (stats) {
          if (stats.streams.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No History Available',
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(mountsWithHistoryProvider.notifier)
                .loadMountsWithHistory(stats.streams);
          });

          final mountsWithHistory =
              mountsWithHistoryAsync.whenOrNull(data: (data) => data) ?? {};
          final activeStreams = stats.streams;

          if (activeStreams.isEmpty) {
            return const EmptyState(icon: Icons.history, title: 'No Streams');
          }

          // Deduplicate mounts by using a map
          final uniqueMounts = <String, StreamInfo>{};
          for (final s in activeStreams) {
            uniqueMounts[s.mount] = s;
          }
          final uniqueStreamList = uniqueMounts.values.toList();

          // Ensure selected value is valid for current server
          String? validValue;
          if (selectedMount != null &&
              uniqueMounts.containsKey(selectedMount)) {
            validValue = selectedMount;
          } else if (uniqueStreamList.isNotEmpty) {
            validValue = uniqueStreamList.first.mount;
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Station',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButton<String>(
                          value: validValue,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: AppColors.surface,
                          items: uniqueStreamList.map((s) {
                            final hasHistory = mountsWithHistory.contains(
                              s.mount,
                            );
                            return DropdownMenuItem(
                              value: s.mount,
                              child: Text(
                                s.name.isNotEmpty ? s.name : s.mount,
                                style: TextStyle(
                                  color: hasHistory || showInactive
                                      ? null
                                      : AppColors.textMuted,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            ref
                                    .read(selectedHistoryMountProvider.notifier)
                                    .state =
                                value;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _HistoryList(mount: validValue ?? '')),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final String mount;
  const _HistoryList({required this.mount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider(mount));

    return historyAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: error.toString()),
      data: (history) {
        if (history.isEmpty) {
          return const EmptyState(icon: Icons.history, title: 'No History');
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final entry = history[index];
            return _HistoryItem(entry: entry);
          },
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
              Icons.music_note,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isNotEmpty ? entry.title : 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (entry.artist.isNotEmpty)
                      Expanded(
                        child: Text(
                          entry.artist,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.listeners}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeFormat.format(entry.playedAt),
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                dateFormat.format(entry.playedAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
