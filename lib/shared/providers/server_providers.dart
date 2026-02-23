import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/models/models.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

class ServerStorage {
  static const String _serversKey = 'tinyice_servers';
  static const String _selectedServerKey = 'tinyice_selected_server';

  final SharedPreferences _prefs;

  ServerStorage(this._prefs);

  List<ServerConnection> getServers() {
    final json = _prefs.getString(_serversKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => ServerConnection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveServers(List<ServerConnection> servers) async {
    final json = jsonEncode(servers.map((e) => e.toJson()).toList());
    await _prefs.setString(_serversKey, json);
  }

  Future<ServerConnection> addServer({
    required String name,
    required String url,
    String? username,
    String? password,
  }) async {
    final servers = getServers();
    final newServer = ServerConnection(
      id: const Uuid().v4(),
      name: name,
      url: url,
      username: username,
      password: password,
      lastConnected: DateTime.now(),
    );
    servers.add(newServer);
    await saveServers(servers);
    return newServer;
  }

  Future<void> updateServer(ServerConnection server) async {
    final servers = getServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      servers[index] = server.copyWith(lastConnected: DateTime.now());
      await saveServers(servers);
    }
  }

  Future<void> removeServer(String id) async {
    final servers = getServers();
    servers.removeWhere((s) => s.id == id);
    await saveServers(servers);
  }

  String? getSelectedServerId() {
    return _prefs.getString(_selectedServerKey);
  }

  Future<void> setSelectedServer(String? id) async {
    if (id == null) {
      await _prefs.remove(_selectedServerKey);
    } else {
      await _prefs.setString(_selectedServerKey, id);
    }
  }
}

extension ServerConnectionExt on ServerConnection {
  ServerConnection copyWith({
    String? id,
    String? name,
    String? url,
    String? username,
    String? password,
    DateTime? lastConnected,
  }) {
    return ServerConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}

final serverStorageProvider = Provider<ServerStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ServerStorage(prefs);
});

class ServersNotifier extends Notifier<List<ServerConnection>> {
  @override
  List<ServerConnection> build() {
    final storage = ref.watch(serverStorageProvider);
    return storage.getServers();
  }

  Future<void> addServer({
    required String name,
    required String url,
    String? username,
    String? password,
  }) async {
    final storage = ref.read(serverStorageProvider);
    final server = await storage.addServer(
      name: name,
      url: url,
      username: username,
      password: password,
    );
    state = [...state, server];
  }

  Future<void> removeServer(String id) async {
    final storage = ref.read(serverStorageProvider);
    await storage.removeServer(id);
    state = state.where((s) => s.id != id).toList();
  }

  Future<void> updateServer(ServerConnection server) async {
    final storage = ref.read(serverStorageProvider);
    await storage.updateServer(server);
    state = state.map((s) => s.id == server.id ? server : s).toList();
  }

  void refresh() {
    final storage = ref.read(serverStorageProvider);
    state = storage.getServers();
  }
}

final serversProvider =
    NotifierProvider<ServersNotifier, List<ServerConnection>>(() {
      return ServersNotifier();
    });

class SelectedServerIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final storage = ref.watch(serverStorageProvider);
    return storage.getSelectedServerId();
  }

  void select(String? id) {
    final storage = ref.read(serverStorageProvider);
    storage.setSelectedServer(id);
    state = id;
  }
}

final selectedServerIdProvider =
    NotifierProvider<SelectedServerIdNotifier, String?>(() {
      return SelectedServerIdNotifier();
    });

final selectedServerProvider = Provider<ServerConnection?>((ref) {
  final serverId = ref.watch(selectedServerIdProvider);
  final servers = ref.watch(serversProvider);

  if (serverId == null) return servers.isNotEmpty ? servers.first : null;
  try {
    return servers.firstWhere((s) => s.id == serverId);
  } catch (_) {
    return servers.isNotEmpty ? servers.first : null;
  }
});
