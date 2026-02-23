import 'package:flutter/foundation.dart';

class StreamInfo {
  final String mount;
  final String name;
  final int listeners;
  final String bitrate;
  final String uptime;
  final String contentType;
  final String sourceIP;
  final int bytesIn;
  final int bytesOut;
  final int bytesDropped;
  final String currentSong;
  final double health;
  final bool isTranscoded;

  StreamInfo({
    required this.mount,
    required this.name,
    required this.listeners,
    required this.bitrate,
    required this.uptime,
    required this.contentType,
    required this.sourceIP,
    required this.bytesIn,
    required this.bytesOut,
    required this.bytesDropped,
    required this.currentSong,
    required this.health,
    required this.isTranscoded,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      mount: json['mount'] ?? '',
      name: json['name'] ?? '',
      listeners: json['listeners'] ?? 0,
      bitrate: json['bitrate'] ?? '',
      uptime: json['uptime'] ?? '',
      contentType: json['type'] ?? '',
      sourceIP: json['ip'] ?? '',
      bytesIn: json['bytes_in'] ?? 0,
      bytesOut: json['bytes_out'] ?? 0,
      bytesDropped: json['bytes_dropped'] ?? 0,
      currentSong: json['song'] ?? '',
      health: (json['health'] ?? 0).toDouble(),
      isTranscoded: json['is_transcoded'] ?? false,
    );
  }
}

class SecurityStats {
  final List<String> bannedIPs;
  final List<String> whitelistedIPs;

  SecurityStats({required this.bannedIPs, required this.whitelistedIPs});

  factory SecurityStats.empty() {
    return SecurityStats(bannedIPs: [], whitelistedIPs: []);
  }

  factory SecurityStats.fromJson(Map<String, dynamic> json) {
    return SecurityStats(
      bannedIPs: List<String>.from(json['banned_ips'] ?? []),
      whitelistedIPs: List<String>.from(json['whitelisted_ips'] ?? []),
    );
  }
}

class StreamerInfo {
  final String name;
  final String mount;
  final int state;
  final String currentSong;
  final int startTime;
  final double duration;
  final int playlistPos;
  final int playlistLen;
  final bool shuffle;
  final bool loop;
  final List<PlaylistItem> queue;
  final List<PlaylistItem> playlist;

  StreamerInfo({
    required this.name,
    required this.mount,
    required this.state,
    required this.currentSong,
    required this.startTime,
    required this.duration,
    required this.playlistPos,
    required this.playlistLen,
    required this.shuffle,
    required this.loop,
    required this.queue,
    required this.playlist,
  });

  bool get isPlaying => state == 1;
  bool get isPaused => state == 2;
  bool get isStopped => state == 0;

  static List<PlaylistItem> _parsePlaylist(dynamic data) {
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  factory StreamerInfo.fromJson(Map<String, dynamic> json) {
    return StreamerInfo(
      name: json['name'] ?? '',
      mount: json['mount'] ?? '',
      state: json['state'] ?? 0,
      currentSong: json['song'] ?? '',
      startTime: json['start_time'] ?? 0,
      duration: (json['duration'] ?? 0).toDouble(),
      playlistPos: json['playlist_pos'] ?? 0,
      playlistLen: json['playlist_len'] ?? 0,
      shuffle: json['shuffle'] ?? false,
      loop: json['loop'] ?? false,
      queue: _parsePlaylist(json['queue']),
      playlist: _parsePlaylist(json['playlist']),
    );
  }
}

class PlaylistItem {
  final String path;
  final String title;
  final int id;

  PlaylistItem({required this.path, required this.title, this.id = 0});

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      path: json['path'] ?? json['Path'] ?? '',
      title: json['title'] ?? json['Title'] ?? '',
      id: json['id'] ?? json['ID'] ?? 0,
    );
  }
}

class TranscoderInfo {
  final String name;
  final String inputMount;
  final String outputMount;
  final String format;
  final int bitrate;
  final bool active;
  final bool enabled;
  final int framesProcessed;
  final int bytesEncoded;
  final String uptime;

  TranscoderInfo({
    required this.name,
    required this.inputMount,
    required this.outputMount,
    required this.format,
    required this.bitrate,
    required this.active,
    required this.enabled,
    this.framesProcessed = 0,
    this.bytesEncoded = 0,
    this.uptime = '',
  });

  factory TranscoderInfo.fromJson(Map<String, dynamic> json) {
    return TranscoderInfo(
      name: json['name'] ?? '',
      inputMount: json['input'] ?? '',
      outputMount: json['output'] ?? '',
      format: json['format'] ?? '',
      bitrate: json['bitrate'] ?? 0,
      active: json['active'] ?? false,
      enabled: json['enabled'] ?? false,
      framesProcessed: json['frames_processed'] ?? 0,
      bytesEncoded: json['bytes_encoded'] ?? 0,
      uptime: json['uptime'] ?? '',
    );
  }

  String get mount => outputMount;
}

class RelayInfo {
  final String url;
  final String mount;
  final bool active;
  final bool enabled;

  RelayInfo({
    required this.url,
    required this.mount,
    required this.active,
    required this.enabled,
  });

  factory RelayInfo.fromJson(Map<String, dynamic> json) {
    return RelayInfo(
      url: json['url'] ?? '',
      mount: json['mount'] ?? '',
      active: json['active'] ?? false,
      enabled: json['enabled'] ?? false,
    );
  }
}

class HistoryEntry {
  final String title;
  final String artist;
  final DateTime playedAt;
  final int listeners;

  HistoryEntry({
    required this.title,
    required this.artist,
    required this.playedAt,
    required this.listeners,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      title: json['title'] ?? json['Song'] ?? '',
      artist: json['artist'] ?? '',
      playedAt:
          DateTime.tryParse(json['played_at'] ?? json['Timestamp'] ?? '') ??
          DateTime.now(),
      listeners: json['listeners'] ?? 0,
    );
  }
}

class ServerConfig {
  final String bindHost;
  final String port;
  final String baseUrl;
  final String pageTitle;
  final String pageSubtitle;
  final bool useHttps;
  final bool autoHttps;
  final String httpsPort;
  final String? acmeEmail;
  final String? acmeDirectoryUrl;
  final List<String> domains;
  final int maxListeners;
  final bool directoryListing;
  final String? directoryServer;
  final bool lowLatencyMode;
  final List<String> bannedIPs;
  final List<String> whitelistedIPs;
  final List<AutoDJConfig> autodjs;

  ServerConfig({
    required this.bindHost,
    required this.port,
    required this.baseUrl,
    required this.pageTitle,
    required this.pageSubtitle,
    required this.useHttps,
    required this.autoHttps,
    required this.httpsPort,
    this.acmeEmail,
    this.acmeDirectoryUrl,
    required this.domains,
    required this.maxListeners,
    required this.directoryListing,
    this.directoryServer,
    required this.lowLatencyMode,
    required this.bannedIPs,
    required this.whitelistedIPs,
    required this.autodjs,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      bindHost: json['bind_host'] ?? '0.0.0.0',
      port: json['port'] ?? '8000',
      baseUrl: json['base_url'] ?? '',
      pageTitle: json['page_title'] ?? 'TinyIce',
      pageSubtitle: json['page_subtitle'] ?? '',
      useHttps: json['use_https'] ?? false,
      autoHttps: json['auto_https'] ?? false,
      httpsPort: json['https_port'] ?? '443',
      acmeEmail: json['acme_email'],
      acmeDirectoryUrl: json['acme_directory_url'],
      domains: List<String>.from(json['domains'] ?? []),
      maxListeners: json['max_listeners'] ?? 100,
      directoryListing: json['directory_listing'] ?? true,
      directoryServer: json['directory_server'],
      lowLatencyMode: json['low_latency_mode'] ?? false,
      bannedIPs: List<String>.from(json['banned_ips'] ?? []),
      whitelistedIPs: List<String>.from(json['whitelisted_ips'] ?? []),
      autodjs:
          (json['autodjs'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AutoDJConfig.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          [],
    );
  }
}

class AutoDJConfig {
  final String name;
  final String mount;
  final String? musicDir;
  final String format;
  final int bitrate;
  final bool enabled;
  final bool loop;
  final bool injectMetadata;
  final bool mpdEnabled;
  final String? mpdPort;
  final String? mpdPassword;

  AutoDJConfig({
    required this.name,
    required this.mount,
    this.musicDir,
    required this.format,
    required this.bitrate,
    required this.enabled,
    required this.loop,
    required this.injectMetadata,
    required this.mpdEnabled,
    this.mpdPort,
    this.mpdPassword,
  });

  factory AutoDJConfig.fromJson(Map<String, dynamic> json) {
    return AutoDJConfig(
      name: json['name'] ?? '',
      mount: json['mount'] ?? '',
      musicDir: json['music_dir'],
      format: json['format'] ?? 'mp3',
      bitrate: json['bitrate'] ?? 128,
      enabled: json['enabled'] ?? false,
      loop: json['loop'] ?? true,
      injectMetadata: json['inject_metadata'] ?? true,
      mpdEnabled: json['mpd_enabled'] ?? false,
      mpdPort: json['mpd_port'],
      mpdPassword: json['mpd_password'],
    );
  }
}

class ServerStats {
  final int bytesIn;
  final int bytesOut;
  final int totalListeners;
  final int totalSources;
  final int totalRelays;
  final int totalStreamers;
  final List<StreamInfo> streams;
  final List<RelayInfo> relays;
  final List<StreamerInfo> streamers;
  final List<String> visibleMounts;
  final int sysRam;
  final int heapAlloc;
  final int stackSys;
  final int numGc;
  final int goroutines;
  final int totalDropped;
  final String serverUptime;

  ServerStats({
    required this.bytesIn,
    required this.bytesOut,
    required this.totalListeners,
    required this.totalSources,
    required this.totalRelays,
    required this.totalStreamers,
    required this.streams,
    required this.relays,
    required this.streamers,
    required this.visibleMounts,
    required this.sysRam,
    required this.heapAlloc,
    required this.stackSys,
    required this.numGc,
    required this.goroutines,
    required this.totalDropped,
    required this.serverUptime,
  });

  factory ServerStats.empty() {
    return ServerStats(
      bytesIn: 0,
      bytesOut: 0,
      totalListeners: 0,
      totalSources: 0,
      totalRelays: 0,
      totalStreamers: 0,
      streams: [],
      relays: [],
      streamers: [],
      visibleMounts: [],
      sysRam: 0,
      heapAlloc: 0,
      stackSys: 0,
      numGc: 0,
      goroutines: 0,
      totalDropped: 0,
      serverUptime: '0s',
    );
  }

  static List<String> _parseVisibleMounts(dynamic data) {
    if (data is Map) {
      return data.keys.map((k) => k.toString()).toList();
    }
    return [];
  }

  factory ServerStats.fromJson(Map<String, dynamic> json) {
    List<StreamInfo> streamsList = [];
    List<RelayInfo> relaysList = [];
    List<StreamerInfo> streamersList = [];

    try {
      if (json['streams'] != null) {
        final streamsData = json['streams'];
        if (streamsData is List) {
          for (var s in streamsData) {
            if (s is Map) {
              streamsList.add(
                StreamInfo.fromJson(Map<String, dynamic>.from(s)),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ServerStats.fromJson: streams error $e');
    }

    try {
      if (json['relays'] != null) {
        final relaysData = json['relays'];
        if (relaysData is List) {
          for (var r in relaysData) {
            if (r is Map) {
              relaysList.add(RelayInfo.fromJson(Map<String, dynamic>.from(r)));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ServerStats.fromJson: relays error $e');
    }

    try {
      if (json['streamers'] != null) {
        final streamersData = json['streamers'];
        if (streamersData is List) {
          for (var s in streamersData) {
            if (s is Map) {
              streamersList.add(
                StreamerInfo.fromJson(Map<String, dynamic>.from(s)),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ServerStats.fromJson: streamers error $e');
    }

    return ServerStats(
      bytesIn: json['bytes_in'] ?? 0,
      bytesOut: json['bytes_out'] ?? 0,
      totalListeners: json['total_listeners'] ?? 0,
      totalSources: json['total_sources'] ?? 0,
      totalRelays: json['total_relays'] ?? 0,
      totalStreamers: json['total_streamers'] ?? 0,
      streams: streamsList,
      relays: relaysList,
      streamers: streamersList,
      visibleMounts: _parseVisibleMounts(json['visible_mounts']),
      sysRam: json['sys_ram'] ?? 0,
      heapAlloc: json['heap_alloc'] ?? 0,
      stackSys: json['stack_sys'] ?? 0,
      numGc: json['num_gc'] ?? 0,
      goroutines: json['goroutines'] ?? 0,
      totalDropped: json['total_dropped'] ?? 0,
      serverUptime: json['server_uptime'] ?? '0s',
    );
  }
}

class User {
  final String username;
  final String role;

  User({required this.username, required this.role});

  bool get isSuperAdmin => role == 'superadmin';
  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(username: json['username'] ?? '', role: json['role'] ?? 'user');
  }
}

class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? csrfToken;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    this.user,
    this.csrfToken,
    this.error,
  });

  factory AuthState.unauthenticated() {
    return AuthState(isAuthenticated: false);
  }

  factory AuthState.authenticated(User user, String csrfToken) {
    return AuthState(isAuthenticated: true, user: user, csrfToken: csrfToken);
  }

  factory AuthState.error(String message) {
    return AuthState(isAuthenticated: false, error: message);
  }
}

class ServerConnection {
  final String id;
  final String name;
  final String url;
  final String? username;
  final String? password;
  final DateTime? lastConnected;

  ServerConnection({
    required this.id,
    required this.name,
    required this.url,
    this.username,
    this.password,
    this.lastConnected,
  });

  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      username: json['username'],
      password: json['password'],
      lastConnected: json['lastConnected'] != null
          ? DateTime.tryParse(json['lastConnected'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'lastConnected': lastConnected?.toIso8601String(),
  };

  String get baseUrl {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}:${uri.port}';
  }

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
