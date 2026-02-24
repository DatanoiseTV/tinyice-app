import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/models/models.dart';
import '../api/endpoints.dart';

class TinyIceApiClient {
  final String baseUrl;
  final Dio _dio;
  String? _csrfToken;
  String? _sessionCookie;
  User? _currentUser;
  bool _isAuthenticated = false;
  CancelToken? _sseCancelToken;

  TinyIceApiClient({required this.baseUrl, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.validateStatus = (status) => status != null && status < 500;
    _dio.options.followRedirects = false;
    _dio.options.maxRedirects = 0;
    _dio.options.receiveDataWhenStatusError = true;
  }

  String get currentBaseUrl => baseUrl;
  bool get isAuthenticated => _isAuthenticated;
  User? get currentUser => _currentUser;
  String? get csrfToken => _csrfToken;

  void _extractSessionCookie(Headers headers) {
    final cookies = headers['set-cookie'];
    if (cookies != null) {
      for (final cookie in cookies) {
        if (cookie.startsWith('sid=')) {
          final match = RegExp(r'sid=([^;]+)').firstMatch(cookie);
          if (match != null) {
            _sessionCookie = 'sid=${match.group(1)}';
          }
        }
        if (cookie.startsWith('csrf_token=')) {
          final match = RegExp(r'csrf_token=([^;]+)').firstMatch(cookie);
          if (match != null) {
            _csrfToken = match.group(1);
          }
        }
      }
    }
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    if (_csrfToken != null) {
      headers['X-CSRF-Token'] = _csrfToken!;
    }
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    headers['Referer'] = '$baseUrl/admin';
    headers['Origin'] = baseUrl;
    return headers;
  }

  Future<ServerStats> getStats() async {
    _sseCancelToken = CancelToken();

    try {
      final response = await _dio.get<ResponseBody>(
        Endpoints.events,
        options: Options(
          headers: _authHeaders,
          responseType: ResponseType.stream,
        ),
        cancelToken: _sseCancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null) {
        return ServerStats.empty();
      }

      await for (final event in stream) {
        final chunk = utf8.decode(event, allowMalformed: true);
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final data = json.decode(jsonStr);
                if (data is Map) {
                  _sseCancelToken?.cancel();
                  _sseCancelToken = null;
                  return ServerStats.fromJson(Map<String, dynamic>.from(data));
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    return ServerStats.empty();
  }

  Stream<ServerStats> subscribeToStats() async* {
    _sseCancelToken = CancelToken();

    while (!_sseCancelToken!.isCancelled) {
      try {
        final response = await _dio.get<ResponseBody>(
          Endpoints.events,
          options: Options(
            headers: _authHeaders,
            responseType: ResponseType.stream,
          ),
          cancelToken: _sseCancelToken,
        );

        final stream = response.data?.stream;
        if (stream != null) {
          String buffer = '';

          await for (final event in stream) {
            if (_sseCancelToken?.isCancelled ?? true) break;

            final chunk = utf8.decode(event, allowMalformed: true);
            buffer += chunk;
            final lines = buffer.split('\n');
            buffer = lines.last;

            for (int i = 0; i < lines.length - 1; i++) {
              final line = lines[i];
              if (line.startsWith('data: ')) {
                final jsonStr = line.substring(6).trim();
                if (jsonStr.isNotEmpty) {
                  try {
                    final data = json.decode(jsonStr);
                    if (data is Map) {
                      yield ServerStats.fromJson(
                        Map<String, dynamic>.from(data),
                      );
                    }
                  } catch (_) {}
                }
              }
            }
          }
        }
      } catch (_) {
        if (_sseCancelToken?.isCancelled ?? true) break;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void stopStatsStream() {
    _sseCancelToken?.cancel();
    _sseCancelToken = null;
  }

  Future<AuthState> login(String username, String password) async {
    try {
      _csrfToken = null;
      _sessionCookie = null;

      final loginPage = await _dio.get(
        baseUrl + Endpoints.login,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      _extractSessionCookie(loginPage.headers);

      final response = await _dio.post(
        Endpoints.login,
        data: {'username': username, 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      _extractSessionCookie(response.headers);

      if (response.statusCode == 302 || response.statusCode == 303) {
        _isAuthenticated = true;

        // Fetch admin page to get CSRF token from session
        final adminPage = await _dio.get(
          baseUrl + Endpoints.admin,
          options: Options(headers: _authHeaders, followRedirects: true),
        );

        // Extract CSRF token from admin page HTML
        final html = adminPage.data?.toString() ?? '';
        final csrfMatch = RegExp(
          r'name="csrf"\s+value="([^"]+)"',
        ).firstMatch(html);
        if (csrfMatch != null) {
          _csrfToken = csrfMatch.group(1);
          debugPrint('[API] login: extracted CSRF token from admin page');
        }

        _currentUser = User(username: username, role: 'admin');
        return AuthState.authenticated(_currentUser!, _csrfToken ?? '');
      }

      if (response.statusCode == 200) {
        final body = response.data?.toString() ?? '';
        if (body.contains('Invalid') || body.contains('error')) {
          return AuthState.error('Invalid username or password');
        }
      }

      return AuthState.error(
        'Login failed with status: ${response.statusCode}',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return AuthState.error('Invalid username or password');
      }
      return AuthState.error('Connection failed: ${e.message}');
    } catch (e) {
      return AuthState.error('Login failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.get(Endpoints.logout);
    } catch (_) {}
    _isAuthenticated = false;
    _currentUser = null;
    _csrfToken = null;
    _sessionCookie = null;
  }

  Future<List<HistoryEntry>> getHistory(String mount) async {
    try {
      final response = await _dio.get(
        Endpoints.history,
        queryParameters: {'mount': mount},
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> toggleStreamer(String mount, String action) async {
    try {
      debugPrint(
        '[API] toggleStreamer: mount=$mount, action=$action, csrf=$_csrfToken',
      );
      String endpoint;
      switch (action) {
        case 'toggle':
          endpoint = Endpoints.playerToggle;
          break;
        case 'next':
          endpoint = Endpoints.playerNext;
          debugPrint('[API] Using next endpoint: $endpoint');
          break;
        case 'prev':
          endpoint = Endpoints.playerPrev;
          break;
        case 'shuffle':
          endpoint = Endpoints.playerShuffle;
          break;
        case 'loop':
          endpoint = Endpoints.playerLoop;
          break;
        case 'restart':
          endpoint = Endpoints.playerRestart;
          debugPrint('[API] Using restart endpoint: $endpoint');
          break;
        case 'scan':
          endpoint = Endpoints.playerScan;
          break;
        case 'clear_queue':
          endpoint = Endpoints.playerClearQueue;
          debugPrint('[API] Using clear_queue endpoint: $endpoint');
          break;
        case 'save_playlist':
          endpoint = Endpoints.playerSavePlaylist;
          break;
        case 'clear_playlist':
          endpoint = Endpoints.playerClearPlaylist;
          break;
        default:
          return false;
      }

      debugPrint('[API] Using endpoint: $endpoint with mount: $mount');
      final formData = FormData();
      formData.fields.add(MapEntry('mount', mount));
      formData.fields.add(MapEntry('csrf', _csrfToken ?? ''));

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          headers: _authHeaders,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      debugPrint('[API] toggleStreamer result: status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] toggleStreamer error: $e');
      return false;
    }
  }

  Future<bool> addMount(String mount, String password) async {
    try {
      final response = await _dio.post(
        Endpoints.mountAdd,
        data: FormData.fromMap({'mount': mount, 'password': password}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeMount(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.mountRemove,
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleMount(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.mountToggle,
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> kickStream(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.kick,
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFallback(String mount, String fallback) async {
    try {
      final response = await _dio.post(
        Endpoints.fallback,
        data: FormData.fromMap({'mount': mount, 'fallback': fallback}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleMountVisible(String mount) async {
    try {
      final response = await _dio.post(
        '/admin/toggle-visible',
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMount({
    required String mount,
    String? password,
    String? fallback,
    bool? visible,
  }) async {
    try {
      final data = {
        'mount': mount,
        if (password != null) 'password': password,
        if (fallback != null) 'fallback': fallback,
        if (visible != null) 'visible': visible,
      };
      final response = await _dio.post(
        Endpoints.mountUpdate,
        data: json.encode(data),
        options: Options(
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> kickAllListeners(String mount) async {
    try {
      final response = await _dio.post(
        '/admin/kick-all-listeners',
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> banIp(String ip) async {
    try {
      debugPrint('[API] banIp: ip=$ip, csrf=$_csrfToken');
      final response = await _dio.post(
        Endpoints.ipBan,
        data: FormData.fromMap({'ip': ip, 'csrf': _csrfToken}),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      debugPrint('[API] banIp result: status=${response.statusCode}');
      return response.statusCode == 302 || response.statusCode == 303;
    } catch (e) {
      debugPrint('[API] banIp error: $e');
      return false;
    }
  }

  Future<bool> unbanIp(String ip) async {
    try {
      final response = await _dio.post(
        Endpoints.ipUnban,
        data: FormData.fromMap({'ip': ip}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> whitelistIp(String ip) async {
    try {
      final response = await _dio.post(
        Endpoints.ipWhitelist,
        data: FormData.fromMap({'ip': ip}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unwhitelistIp(String ip) async {
    try {
      final response = await _dio.post(
        Endpoints.ipUnwhitelist,
        data: FormData.fromMap({'ip': ip}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<SecurityStats> getSecurityStats() async {
    try {
      final response = await _dio.get(
        Endpoints.stats,
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200) {
        return SecurityStats.fromJson(response.data);
      }
      return SecurityStats.empty();
    } catch (_) {
      return SecurityStats.empty();
    }
  }

  Future<bool> addUser(String username, String password) async {
    try {
      debugPrint('[API] addUser: username=$username, csrf=$_csrfToken');
      final response = await _dio.post(
        Endpoints.userAdd,
        data: FormData.fromMap({
          'username': username,
          'password': password,
          'csrf': _csrfToken,
        }),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      debugPrint('[API] addUser result: status=${response.statusCode}');
      return response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] addUser error: $e');
      return false;
    }
  }

  Future<bool> removeUser(String username) async {
    try {
      final response = await _dio.post(
        Endpoints.userRemove,
        data: FormData.fromMap({'username': username, 'csrf': _csrfToken}),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<User>> getUsers() async {
    try {
      final response = await _dio.get(
        Endpoints.userList,
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> toggleRelay(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.relayToggle,
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restartRelay(String mount) async {
    try {
      final response = await _dio.post(
        '/admin/restart-relay',
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRelay(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.relayRemove,
        data: FormData.fromMap({'mount': mount}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addRelay(
    String source,
    String mount, {
    String? password,
    int burstSize = 20,
  }) async {
    try {
      final response = await _dio.post(
        Endpoints.relayAdd,
        data: FormData.fromMap({
          'source': source,
          'mount': mount,
          if (password != null && password.isNotEmpty) 'password': password,
          'burst_size': burstSize,
          'csrf': _csrfToken,
        }),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<TranscoderInfo>> getTranscoderStats() async {
    try {
      final response = await _dio.get(
        Endpoints.transcoderStats,
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => TranscoderInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> addTranscoder(
    String input,
    String output, {
    String? name,
    String format = 'opus',
    int bitrate = 128,
  }) async {
    try {
      final response = await _dio.post(
        Endpoints.transcoderAdd,
        data: FormData.fromMap({
          'input': input,
          'output': output,
          if (name != null && name.isNotEmpty) 'name': name,
          'format': format,
          'bitrate': bitrate,
          'csrf': _csrfToken,
        }),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleTranscoder(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.transcoderToggle,
        data: FormData.fromMap({'mount': mount, 'csrf': _csrfToken}),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTranscoder(String mount) async {
    try {
      final response = await _dio.post(
        Endpoints.transcoderDelete,
        data: FormData.fromMap({'mount': mount, 'csrf': _csrfToken}),
        options: Options(
          headers: _authHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearAuthLockout() async {
    try {
      final response = await _dio.post(
        '/admin/clear-auth-lockout',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearScanLockout() async {
    try {
      final response = await _dio.post(
        '/admin/clear-scan-lockout',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addWebhook(String url) async {
    try {
      final response = await _dio.post(
        '/admin/webhook/add',
        data: FormData.fromMap({'url': url}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteWebhook(String url) async {
    try {
      final response = await _dio.post(
        '/admin/webhook/delete',
        data: FormData.fromMap({'url': url}),
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 302 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> sendWebRTCSourceOffer(
    String mount,
    Map<String, dynamic> offer,
  ) async {
    try {
      final response = await _dio.post(
        '${Endpoints.webrtcSourceOffer}?mount=${Uri.encodeComponent(mount)}',
        data: json.encode(offer),
        options: Options(
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
        ),
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> stopWebRTCSource(String mount) async {
    try {
      final response = await _dio.post(
        '${Endpoints.webrtcSourceStop}?mount=${Uri.encodeComponent(mount)}',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  String getStreamUrl(String mount) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'https' : 'http';
    return '$scheme://${uri.host}:$uri.port$mount';
  }

  Future<bool> addAutoDJ({
    required String name,
    required String mount,
    String? musicDir,
    String format = 'mp3',
    int bitrate = 128,
    bool enabled = true,
    bool loop = true,
    bool injectMetadata = true,
    bool mpdEnabled = false,
    String? mpdPort,
    String? mpdPassword,
  }) async {
    try {
      final data = {
        'name': name,
        'mount': mount,
        if (musicDir != null) 'music_dir': musicDir,
        'format': format,
        'bitrate': bitrate,
        'enabled': enabled,
        'loop': loop,
        'inject_metadata': injectMetadata,
        'mpd_enabled': mpdEnabled,
        if (mpdPort != null) 'mpd_port': mpdPort,
        if (mpdPassword != null) 'mpd_password': mpdPassword,
      };
      final response = await _dio.post(
        Endpoints.autodjAdd,
        data: json.encode(data),
        options: Options(
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> editAutoDJ({
    required String name,
    required String mount,
    String? musicDir,
    String format = 'mp3',
    int bitrate = 128,
    bool enabled = true,
    bool loop = true,
    bool injectMetadata = true,
    bool mpdEnabled = false,
    String? mpdPort,
    String? mpdPassword,
  }) async {
    try {
      final data = {
        'name': name,
        'mount': mount,
        if (musicDir != null) 'music_dir': musicDir,
        'format': format,
        'bitrate': bitrate,
        'enabled': enabled,
        'loop': loop,
        'inject_metadata': injectMetadata,
        'mpd_enabled': mpdEnabled,
        if (mpdPort != null) 'mpd_port': mpdPort,
        if (mpdPassword != null) 'mpd_password': mpdPassword,
      };
      final response = await _dio.post(
        Endpoints.autodjEdit,
        data: json.encode(data),
        options: Options(
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeAutoDJ(String mount) async {
    try {
      final response = await _dio.post(
        '${Endpoints.autodjRemove}?mount=${Uri.encodeComponent(mount)}',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    try {
      final response = await _dio.get(
        Endpoints.events,
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPublicEvents() async {
    try {
      final response = await _dio.get(Endpoints.publicEvents);
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLegacyStats() async {
    try {
      final response = await _dio.get(Endpoints.legacyStats);
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInsights() async {
    try {
      final response = await _dio.get(
        Endpoints.insights,
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleLatency() async {
    try {
      final response = await _dio.post(
        Endpoints.latencyToggle,
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hotSwap(String fromMount, String toMount) async {
    try {
      final response = await _dio.post(
        '${Endpoints.hotSwap}?from=${Uri.encodeComponent(fromMount)}&to=${Uri.encodeComponent(toMount)}',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loadPlaylist(String mount, String playlistName) async {
    try {
      final response = await _dio.post(
        '${Endpoints.streamerLoadPlaylist}?mount=${Uri.encodeComponent(mount)}&name=${Uri.encodeComponent(playlistName)}',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearPlaylist(String mount) async {
    try {
      final response = await _dio.post(
        '${Endpoints.streamerClearPlaylist}?mount=${Uri.encodeComponent(mount)}',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  Future<List<MusicFile>> getMusicFiles(String mount, {String? path}) async {
    try {
      final queryParams = <String, dynamic>{'mount': mount};
      if (path != null) queryParams['path'] = path;

      final response = await _dio.get(
        Endpoints.playerFiles,
        queryParameters: queryParams,
        options: Options(headers: _authHeaders),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => MusicFile.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[API] getMusicFiles error: $e');
      return [];
    }
  }

  Future<bool> addToQueue(String mount, String filePath) async {
    try {
      debugPrint('[API] addToQueue: mount=$mount, path=$filePath');
      final formData = FormData();
      formData.fields.add(MapEntry('mount', mount));
      formData.fields.add(MapEntry('path', filePath));
      formData.fields.add(MapEntry('action', 'add'));
      formData.fields.add(MapEntry('csrf', _csrfToken ?? ''));

      final response = await _dio.post(
        Endpoints.playerQueue,
        data: formData,
        options: Options(
          headers: _authHeaders,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      debugPrint('[API] addToQueue result: status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] addToQueue error: $e');
      return false;
    }
  }

  Future<bool> addToPlaylist(String mount, String filePath) async {
    try {
      debugPrint('[API] addToPlaylist: mount=$mount, file=$filePath');
      final formData = FormData();
      formData.fields.add(MapEntry('mount', mount));
      formData.fields.add(MapEntry('file', filePath));
      formData.fields.add(MapEntry('action', 'add'));
      formData.fields.add(MapEntry('csrf', _csrfToken ?? ''));

      debugPrint('[API] addToPlaylist formData fields: ${formData.fields}');
      final response = await _dio.post(
        Endpoints.playerPlaylistAction,
        data: formData,
        options: Options(
          headers: _authHeaders,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      debugPrint('[API] addToPlaylist result: status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] addToPlaylist error: $e');
      return false;
    }
  }
}
