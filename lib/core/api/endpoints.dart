class Endpoints {
  static const String login = '/login';
  static const String logout = '/logout';
  static const String admin = '/admin';
  static const String events = '/admin/events';
  static const String stats = '/admin/stats';
  static const String publicEvents = '/events';
  static const String legacyStats = '/status-json.xsl';
  static const String history = '/admin/history';
  static const String insights = '/admin/insights';
  static const String securityStats = '/admin/security-stats';

  // Mount management
  static const String mountAdd = '/admin/mount/add';
  static const String mountRemove = '/admin/mount/remove';
  static const String mountToggle = '/admin/mount/toggle';
  static const String mountVisible = '/admin/mount/visible';
  static const String kick = '/admin/kick';
  static const String kickAll = '/admin/kickall';
  static const String fallback = '/admin/fallback';

  // Streamer/AutoDJ
  static const String streamerStart = '/streamer/start';
  static const String streamerStop = '/streamer/stop';
  static const String streamerToggle = '/streamer/toggle';
  static const String streamerNext = '/streamer/next';
  static const String streamerScan = '/streamer/scan';
  static const String streamerSavePlaylist = '/streamer/save_playlist';
  static const String streamerLoadPlaylist = '/streamer/load_playlist';
  static const String streamerClearPlaylist = '/streamer/clear_playlist';
  static const String streamerClearQueue = '/streamer/clear_queue';
  static const String streamerPlaylist = '/streamer/playlist';
  static const String streamerQueue = '/streamer/queue';
  static const String streamerShuffle = '/streamer/shuffle';
  static const String streamerLoop = '/streamer/loop';
  static const String streamerMeta = '/streamer/meta';
  static const String streamerRestart = '/streamer/restart';
  static const String streamerFiles = '/streamer/files';
  static const String autodjAdd = '/admin/autodj/add';
  static const String autodjRemove = '/admin/autodj/remove';
  static const String autodjEdit = '/admin/autodj/edit';

  // User management
  static const String userAdd = '/admin/add-user';
  static const String userRemove = '/admin/remove-user';
  static const String userList = '/admin/users';

  // IP management
  static const String ipBan = '/admin/add-banned-ip';
  static const String ipUnban = '/admin/remove-banned-ip';
  static const String ipWhitelist = '/admin/add-whitelisted-ip';
  static const String ipUnwhitelist = '/admin/remove-whitelisted-ip';

  // Relay management
  static const String relayAdd = '/admin/relay/add';
  static const String relayRemove = '/admin/relay/remove';
  static const String relayToggle = '/admin/relay/toggle';

  // Transcoder management
  static const String transcoderStats = '/admin/transcoder-stats';
  static const String transcoderAdd = '/admin/add-transcoder';
  static const String transcoderToggle = '/admin/toggle-transcoder';
  static const String transcoderDelete = '/admin/delete-transcoder';

  // Webhooks
  static const String webhookAdd = '/admin/webhook/add';
  static const String webhookRemove = '/admin/webhook/remove';

  // WebRTC / Go Live
  static const String webrtcSourceOffer = '/webrtc/source-offer';

  // Server
  static const String latencyToggle = '/admin/toggle_latency';
  static const String hotSwap = '/admin/hotswap';
}
