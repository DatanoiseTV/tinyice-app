import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/models/models.dart';
import '../../shared/providers/server_providers.dart';
import '../auth/auth_provider.dart';

class AddServerScreen extends ConsumerStatefulWidget {
  final ServerConnection? editServer;

  const AddServerScreen({super.key, this.editServer});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _serverUrlController = TextEditingController();
  final _serverNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showHttpWarning = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.addListener(_checkHttpWarning);

    if (widget.editServer != null) {
      _serverNameController.text = widget.editServer!.name;
      _serverUrlController.text = widget.editServer!.url;
      _usernameController.text = widget.editServer!.username ?? '';
      _passwordController.text = widget.editServer!.password ?? '';
    }
  }

  void _checkHttpWarning() {
    final url = _serverUrlController.text.trim().toLowerCase();
    final isHttp = url.startsWith('http://') && !url.startsWith('https://');
    if (isHttp != _showHttpWarning) {
      setState(() => _showHttpWarning = isHttp);
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _serverNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Server'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _serverNameController,
                      decoration: const InputDecoration(
                        labelText: 'Server Name',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://radio.example.com',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    if (_showHttpWarning) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withAlpha(76),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              color: AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Using HTTP transmits all data in clear text, including passwords.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Credentials (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _addServer,
                  child: const Text('Add Server'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addServer() async {
    if (_serverUrlController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter server URL')));
      return;
    }

    final name = _serverNameController.text.isNotEmpty
        ? _serverNameController.text
        : Uri.tryParse(_serverUrlController.text)?.host ?? 'Server';

    if (widget.editServer != null) {
      final updated = widget.editServer!.copyWith(
        name: name,
        url: _serverUrlController.text,
        username: _usernameController.text.isNotEmpty
            ? _usernameController.text
            : null,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
      );
      await ref.read(serversProvider.notifier).updateServer(updated);
    } else {
      await ref
          .read(serversProvider.notifier)
          .addServer(
            name: name,
            url: _serverUrlController.text,
            username: _usernameController.text.isNotEmpty
                ? _usernameController.text
                : null,
            password: _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
          );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
