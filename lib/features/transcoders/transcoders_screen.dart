import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';

final transcodersProvider = FutureProvider<List<TranscoderInfo>>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return [];
  return client.getTranscoderStats();
});

class TranscodersScreen extends ConsumerWidget {
  const TranscodersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transcoders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(transcodersProvider),
          ),
        ],
      ),
      body: ref
          .watch(transcodersProvider)
          .when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(transcodersProvider),
            ),
            data: (transcoders) {
              if (transcoders.isEmpty) {
                return const EmptyState(
                  icon: Icons.transcribe,
                  title: 'No Transcoders',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transcoders.length,
                itemBuilder: (context, index) {
                  return _TranscoderTile(transcoder: transcoders[index]);
                },
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTranscoderDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTranscoderDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final inputController = TextEditingController();
    final outputController = TextEditingController();
    String format = 'opus';
    int bitrate = 128;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
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
                    'Add Transcoder',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'MP3 to Opus',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: inputController,
                    decoration: const InputDecoration(
                      labelText: 'Input Mount',
                      hintText: '/source-stream',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: outputController,
                    decoration: const InputDecoration(
                      labelText: 'Output Mount',
                      hintText: '/stream-opus',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: format,
                          decoration: const InputDecoration(
                            labelText: 'Format',
                          ),
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(
                              value: 'opus',
                              child: Text('Opus'),
                            ),
                            DropdownMenuItem(value: 'mp3', child: Text('MP3')),
                          ],
                          onChanged: (v) => setState(() => format = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Bitrate (kbps)',
                          ),
                          controller: TextEditingController(
                            text: bitrate.toString(),
                          ),
                          onChanged: (v) => bitrate = int.tryParse(v) ?? 128,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final client = ref.read(apiClientProvider);
                        if (client == null) return;
                        final name = nameController.text.trim();
                        final input = inputController.text.trim();
                        final output = outputController.text.trim();
                        if (name.isEmpty || input.isEmpty || output.isEmpty)
                          return;

                        final success = await client.addTranscoder(
                          input,
                          output,
                          name: name,
                          format: format,
                          bitrate: bitrate,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.invalidate(transcodersProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Transcoder added'
                                    : 'Failed to add transcoder',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Add Transcoder'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscoderTile extends ConsumerWidget {
  final TranscoderInfo transcoder;

  const _TranscoderTile({required this.transcoder});

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
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: transcoder.active ? AppColors.success : AppColors.offline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transcoder.name.isNotEmpty
                      ? transcoder.name
                      : transcoder.outputMount,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transcoder.inputMount} -> ${transcoder.outputMount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _buildChip(
                      transcoder.format.toUpperCase(),
                      AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildChip('${transcoder.bitrate}kbps', AppColors.success),
                    if (transcoder.active && transcoder.uptime.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildChip(transcoder.uptime, AppColors.textMuted),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            color: AppColors.surface,
            onSelected: (value) async {
              final client = ref.read(apiClientProvider);
              if (client == null) return;

              if (value == 'toggle') {
                final success = await client.toggleTranscoder(
                  transcoder.outputMount,
                );
                if (context.mounted) {
                  ref.invalidate(transcodersProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Transcoder toggled' : 'Failed to toggle',
                      ),
                    ),
                  );
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Transcoder'),
                    content: Text(
                      'Delete transcoder ${transcoder.outputMount}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final success = await client.deleteTranscoder(
                    transcoder.outputMount,
                  );
                  if (context.mounted) {
                    ref.invalidate(transcodersProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Transcoder deleted' : 'Failed to delete',
                        ),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      transcoder.active ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(transcoder.active ? 'Stop' : 'Start'),
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

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
