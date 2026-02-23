import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_macos_permissions/flutter_macos_permissions.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';

class GoLiveScreen extends ConsumerStatefulWidget {
  const GoLiveScreen({super.key});

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  bool _isLive = false;
  bool _isStarting = false;
  String _status = 'READY TO BROADCAST';
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  List<MediaDeviceInfo> _audioInputs = [];
  String? _selectedDeviceId;
  final _mountController = TextEditingController(text: '/live');
  double _audioLevel = 0;
  Timer? _levelTimer;

  @override
  void initState() {
    super.initState();
    _initDevices();
  }

  @override
  void dispose() {
    _stopBroadcast();
    _mountController.dispose();
    _levelTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDevices() async {
    if (Platform.isIOS) {
      setState(() {
        _audioInputs = [];
      });
      return;
    }

    try {
      String status = await FlutterMacosPermissions.microphoneStatus();
      debugPrint('Microphone permission status: $status');

      if (status == 'denied' || status == 'notDetermined') {
        final granted = await FlutterMacosPermissions.requestMicrophone();
        debugPrint('Microphone permission granted: $granted');
        if (!granted) {
          setState(() {
            _audioInputs = [];
          });
          return;
        }
      } else if (status == 'restricted') {
        setState(() {
          _audioInputs = [];
        });
        return;
      }

      final devices = await navigator.mediaDevices.enumerateDevices();
      setState(() {
        _audioInputs = devices.where((d) => d.kind == 'audioInput').toList();
        if (_audioInputs.isNotEmpty) {
          _selectedDeviceId = _audioInputs.first.deviceId;
        }
      });
    } catch (e) {
      debugPrint('Error getting devices or permission: $e');
      setState(() {
        _audioInputs = [];
      });
    }
  }

  Future<void> _startBroadcast() async {
    if (_isLive || _isStarting) return;

    setState(() {
      _isStarting = true;
    });

    try {
      final constraints = <String, dynamic>{
        'audio': _selectedDeviceId != null
            ? {
                'deviceId': {'exact': _selectedDeviceId},
              }
            : {
                'echoCancellation': false,
                'noiseSuppression': false,
                'autoGainControl': false,
              },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      _pc = await createPeerConnection(config);

      _pc!.onIceConnectionState = (state) {
        debugPrint('ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          setState(() {
            _status = 'LIVE ON ${_mountController.text.toUpperCase()}';
          });
        } else if (state ==
                RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          if (_isLive) {
            _stopBroadcast();
          }
        }
      };

      _localStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      final client = ref.read(apiClientProvider);
      if (client == null) throw Exception('Not connected');

      final answer = await client.sendWebRTCSourceOffer(_mountController.text, {
        'type': offer.type,
        'sdp': offer.sdp,
      });

      if (answer == null) {
        throw Exception('Failed to get answer from server');
      }

      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          answer['sdp'] as String,
          answer['type'] as String,
        ),
      );

      _startAudioLevelMonitoring();

      setState(() {
        _isLive = true;
        _isStarting = false;
        _status = 'CONNECTING...';
      });
    } catch (e) {
      debugPrint('Error starting broadcast: $e');
      _stopBroadcast();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start: $e')));
      }
    }
  }

  void _startAudioLevelMonitoring() {
    _levelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      if (_localStream == null || !_isLive || _pc == null) return;

      try {
        double maxLevel = 0;

        final senders = await _pc!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'audio') {
            final stats = await sender.getStats();
            for (final report in stats) {
              if (report.type == 'outbound-rtp') {
                final level = report.values['audioLevel'];
                if (level != null) {
                  final db = double.tryParse(level.toString()) ?? -100;
                  if (db > -100) {
                    maxLevel = ((db + 100) / 100).clamp(0.0, 1.0);
                  }
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _audioLevel = maxLevel > 0.01 ? maxLevel : (_audioLevel * 0.7);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _audioLevel = _audioLevel * 0.7;
          });
        }
      }
    });
  }

  void _stopBroadcast() {
    _levelTimer?.cancel();
    _levelTimer = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    _pc?.close();
    _pc = null;

    if (mounted) {
      setState(() {
        _isLive = false;
        _isStarting = false;
        _status = 'READY TO BROADCAST';
        _audioLevel = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Go Live'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isLive
                  ? AppColors.success.withAlpha(25)
                  : Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLive) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isLive ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVisualization(),
            const SizedBox(height: 24),
            _buildAudioInputSelector(),
            const SizedBox(height: 16),
            _buildMountInput(),
            const SizedBox(height: 24),
            _buildGoLiveButton(),
            const SizedBox(height: 24),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualization() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: CustomPaint(
        painter: _SpectrumPainter(level: _audioLevel),
        size: const Size(double.infinity, 200),
      ),
    );
  }

  Widget _buildAudioInputSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUDIO INPUT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (_audioInputs.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No microphone found. On simulator, audio input is not available. Test on a real device.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedDeviceId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              dropdownColor: AppColors.surface,
              items: _audioInputs.map((device) {
                return DropdownMenuItem(
                  value: device.deviceId,
                  child: Text(
                    device.label.isNotEmpty ? device.label : 'Microphone',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: _isLive
                  ? null
                  : (value) {
                      setState(() {
                        _selectedDeviceId = value;
                      });
                    },
            ),
        ],
      ),
    );
  }

  Widget _buildMountInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MOUNT POINT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mountController,
            enabled: !_isLive,
            decoration: const InputDecoration(
              hintText: '/live',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoLiveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isStarting
            ? null
            : () {
                if (_isLive) {
                  _stopBroadcast();
                } else {
                  _startBroadcast();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLive ? AppColors.error : AppColors.primary,
          foregroundColor: _isLive ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 8,
          shadowColor: (_isLive ? AppColors.error : AppColors.primary)
              .withAlpha(77),
        ),
        child: _isStarting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isLive ? Icons.stop : Icons.radio),
                  const SizedBox(width: 8),
                  Text(
                    _isLive ? 'STOP BROADCAST' : 'GO LIVE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'WebRTC uses the Opus codec directly from your device to the server with ultra-low latency.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final double level;

  _SpectrumPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    const barCount = 32;
    final barWidth = size.width / barCount - 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + 2);
      final barHeight = level > 0
          ? (level * size.height * (0.3 + (i / barCount) * 0.7))
          : 4.0;

      final hue = 180 + (i / barCount) * 60;
      paint.color = HSLColor.fromAHSL(1, hue, 1, 0.5).toColor();

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.level != level;
  }
}
