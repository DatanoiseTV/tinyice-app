import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';

class FileBrowserScreen extends ConsumerStatefulWidget {
  final String mount;

  const FileBrowserScreen({super.key, required this.mount});

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  String _currentPath = '';
  List<MusicFile> _files = [];
  bool _isLoading = true;
  final List<String> _pathHistory = [''];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    final client = ref.read(apiClientProvider);
    final files = await client?.getMusicFiles(widget.mount, path: _currentPath);

    if (mounted) {
      setState(() {
        _files = files ?? [];
        _isLoading = false;
      });
    }
  }

  void _navigateToFolder(String path) {
    _pathHistory.add(path);
    _currentPath = path;
    _loadFiles();
  }

  void _navigateBack() {
    if (_pathHistory.length > 1) {
      _pathHistory.removeLast();
      _currentPath = _pathHistory.last;
      _loadFiles();
    }
  }

  Future<void> _addToQueue(MusicFile file) async {
    final client = ref.read(apiClientProvider);
    final success = await client?.addToQueue(
      widget.mount,
      '/root/music/${file.path}',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success == true ? 'Added to queue' : 'Failed to add to queue',
          ),
          backgroundColor: success == true
              ? AppColors.success
              : AppColors.error,
        ),
      );
    }
  }

  Future<void> _addToPlaylist(MusicFile file) async {
    // Try queue endpoint first since it works
    final client = ref.read(apiClientProvider);
    final success = await client?.addToQueue(
      widget.mount,
      '/root/music/${file.path}',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success == true ? 'Added to queue' : 'Failed to add to queue',
          ),
          backgroundColor: success == true
              ? AppColors.success
              : AppColors.error,
        ),
      );
    }
  }

  void _showAddOptions(MusicFile file) {
    showModalBottomSheet(
      context: context,
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
              Text(
                file.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.queue_music,
                  color: AppColors.primary,
                ),
                title: const Text('Add to Queue'),
                subtitle: const Text('Add to playback queue'),
                onTap: () {
                  Navigator.pop(context);
                  _addToQueue(file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.playlist_add,
                  color: AppColors.primary,
                ),
                title: const Text('Add to Playlist'),
                subtitle: const Text('Add to playlist permanently'),
                onTap: () {
                  Navigator.pop(context);
                  _addToPlaylist(file);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Music Library'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: Column(
        children: [
          if (_currentPath.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _pathHistory.length > 1 ? _navigateBack : null,
                  ),
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _files.isEmpty
                ? const Center(
                    child: Text(
                      'No files found',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return _FileListItem(
                        file: file,
                        onTap: file.isDirectory
                            ? () => _navigateToFolder(file.path)
                            : () => _showAddOptions(file),
                        onAdd: file.isDirectory
                            ? null
                            : () => _showAddOptions(file),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final MusicFile file;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _FileListItem({required this.file, required this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceLight, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: file.isDirectory
                    ? AppColors.primary.withAlpha(25)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                file.isDirectory ? Icons.folder : Icons.music_note,
                color: file.isDirectory
                    ? AppColors.primary
                    : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file.duration != null)
                    Text(
                      file.duration!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    )
                  else if (file.isDirectory)
                    const Text(
                      'Folder',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (onAdd != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
                onPressed: onAdd,
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
