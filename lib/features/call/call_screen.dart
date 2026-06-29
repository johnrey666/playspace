import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../shared/models/call_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/call_service.dart';
import '../../shared/widgets/avatar_widget.dart';

/// The live 1:1 call experience (works for both audio and video). Sets up a
/// WebRTC peer connection, exchanges signaling through [CallService] and renders
/// the appropriate UI. Media is peer-to-peer over free Google STUN servers.
///
/// For the caller the call document is created here (so tapping a call button
/// opens this screen instantly); the callee is handed an existing [callId].
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    this.callId,
    required this.isCaller,
    required this.type,
    required this.otherName,
    this.otherPhoto,
    this.me,
    this.other,
  })  : assert(isCaller || callId != null,
            'callee must be given an existing callId'),
        assert(!isCaller || (me != null && other != null),
            'caller must provide both user models');

  /// Existing call id (callee side). For the caller it is created on the fly.
  final String? callId;
  final bool isCaller;
  final CallType type;
  final String otherName;
  final String? otherPhoto;
  // Caller-only: used to create the call document.
  final UserModel? me;
  final UserModel? other;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const Map<String, dynamic> _config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  late final CallService _calls = context.read<CallService>();

  String? _callId;

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingCandidates = [];

  StreamSubscription? _callSub;
  StreamSubscription? _candSub;
  Timer? _durationTimer;

  bool _remoteDescSet = false;
  bool _connected = false;
  bool _popped = false;
  bool _micOn = true;
  bool _camOn = true;
  late bool _speakerOn = widget.type == CallType.video;
  bool _failed = false;
  String _statusLabel = 'Calling…';
  Duration _elapsed = Duration.zero;

  bool get _isVideo => widget.type == CallType.video;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final ok = await _ensurePermissions();
    if (!ok) {
      if (mounted) {
        setState(() {
          _statusLabel = 'Microphone/camera permission needed';
          _failed = true;
        });
      }
      return;
    }

    try {
      // Resolve the signaling document. The caller creates it now so the call
      // UI is already on screen by the time this runs.
      if (widget.isCaller) {
        _callId = await _calls.createCall(
          me: widget.me!,
          other: widget.other!,
          type: widget.type,
        );
      } else {
        _callId = widget.callId;
      }

      _pc = await createPeerConnection(_config);
      await _openUserMedia();
      _wirePeer();
      _listenSignaling();
      if (widget.isCaller) {
        await _makeOffer();
        if (mounted) setState(() => _statusLabel = 'Ringing…');
      } else {
        if (mounted) setState(() => _statusLabel = 'Connecting…');
      }
    } catch (_) {
      _statusLabel = 'Call failed';
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<bool> _ensurePermissions() async {
    final perms = <Permission>[
      Permission.microphone,
      if (_isVideo) Permission.camera,
    ];
    final results = await perms.request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<void> _openUserMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _isVideo ? {'facingMode': 'user'} : false,
    });
    _localStream = stream;
    _localRenderer.srcObject = stream;
    for (final track in stream.getTracks()) {
      await _pc!.addTrack(track, stream);
    }
    await _applyAudioRoute();
    if (mounted) setState(() {});
  }

  void _wirePeer() {
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || _callId == null) return;
      _calls.addCandidate(
        _callId!,
        fromCaller: widget.isCaller,
        candidate: candidate.toMap().cast<String, dynamic>(),
      );
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        if (mounted) setState(() => _connected = true);
        _startDurationTimer();
      }
    };
    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        // Leave it to the signaling listener / user to end.
      }
    };
  }

  void _listenSignaling() {
    final id = _callId!;
    _candSub = _calls
        .remoteCandidates(id, iAmCaller: widget.isCaller)
        .listen((list) {
      for (final c in list) {
        final cand = RTCIceCandidate(
          c['candidate'] as String?,
          c['sdpMid'] as String?,
          (c['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteDescSet) {
          _pc?.addCandidate(cand);
        } else {
          _pendingCandidates.add(cand);
        }
      }
    });

    _callSub = _calls.callStream(id).listen(_onCall);
  }

  Future<void> _onCall(CallModel? call) async {
    if (call == null ||
        call.status == CallStatus.ended ||
        call.status == CallStatus.declined) {
      _statusLabel =
          call?.status == CallStatus.declined ? 'Call declined' : 'Call ended';
      _hangUpLocally(notifyRemote: false);
      return;
    }

    if (widget.isCaller) {
      final answer = call.answer;
      if (answer != null && !_remoteDescSet) {
        await _pc!.setRemoteDescription(
            RTCSessionDescription(answer['sdp'] as String?, answer['type'] as String?));
        _remoteDescSet = true;
        _flushCandidates();
        if (mounted) setState(() => _statusLabel = 'Connecting…');
      }
    } else {
      final offer = call.offer;
      if (offer != null && !_remoteDescSet) {
        await _pc!.setRemoteDescription(
            RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?));
        _remoteDescSet = true;
        _flushCandidates();
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        await _calls.setAnswer(
            _callId!, answer.toMap().cast<String, dynamic>());
      }
    }
  }

  Future<void> _makeOffer() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await _pc!.setLocalDescription(offer);
    await _calls.setOffer(_callId!, offer.toMap().cast<String, dynamic>());
  }

  void _flushCandidates() {
    for (final c in _pendingCandidates) {
      _pc?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  void _startDurationTimer() {
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _applyAudioRoute() async {
    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
    } catch (_) {/* not supported on some platforms */}
  }

  // ---- Controls ----
  void _toggleMic() {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    _micOn = !_micOn;
    for (final t in tracks) {
      t.enabled = _micOn;
    }
    setState(() {});
  }

  void _toggleCam() {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    _camOn = !_camOn;
    for (final t in tracks) {
      t.enabled = _camOn;
    }
    setState(() {});
  }

  void _toggleSpeaker() {
    _speakerOn = !_speakerOn;
    _applyAudioRoute();
    setState(() {});
  }

  Future<void> _switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (_) {}
  }

  /// Ends the call: tells the remote peer (best effort) and pops. The actual
  /// media teardown happens once, in [dispose], so renderers are never touched
  /// after being released.
  Future<void> _hangUpLocally({bool notifyRemote = true}) async {
    if (_popped) return;
    _popped = true;
    final id = _callId;
    if (notifyRemote && id != null) {
      await _calls.hangUp(id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // Best-effort: make sure the peer knows the call is over.
    final id = _callId;
    if (id != null) _calls.hangUp(id);
    _durationTimer?.cancel();
    _callSub?.cancel();
    _candSub?.cancel();
    for (final t in _localStream?.getTracks() ?? []) {
      t.stop();
    }
    _localStream?.dispose();
    _pc?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String get _timer {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUpLocally();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isVideo ? _buildVideo() : _buildAudio(),
      ),
    );
  }

  // ---- Video layout ----
  Widget _buildVideo() {
    return Stack(
      children: [
        Positioned.fill(
          child: _connected
              ? RTCVideoView(_remoteRenderer,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : _waitingBackdrop(),
        ),
        // Local preview.
        Positioned(
          top: 50,
          right: 16,
          child: Container(
            width: 110,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            clipBehavior: Clip.antiAlias,
            child: (_camOn && _localStream != null)
                ? RTCVideoView(_localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : Container(
                    color: Colors.black54,
                    child: const Center(
                        child: Icon(Icons.videocam_off_rounded,
                            color: Colors.white54)),
                  ),
          ),
        ),
        if (!_connected)
          Align(
            alignment: const Alignment(0, -0.3),
            child: _callerHeader(light: true),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _controlBar(),
        ),
      ],
    );
  }

  Widget _waitingBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2544), Color(0xFF0E0F1A)],
        ),
      ),
    );
  }

  // ---- Audio layout ----
  Widget _buildAudio() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2D5B), Color(0xFF0E0F1A)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            _callerHeader(light: true),
            const Spacer(),
            _controlBar(),
          ],
        ),
      ),
    );
  }

  Widget _callerHeader({bool light = false}) {
    final color = light ? Colors.white : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarWidget(
          photoUrl: widget.otherPhoto,
          displayName: widget.otherName,
          size: 120,
        ),
        const SizedBox(height: 20),
        Text(
          widget.otherName,
          style: TextStyle(
              color: color, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _failed
              ? _statusLabel
              : (_connected ? _timer : _statusLabel),
          style: TextStyle(
              color: (color ?? Colors.black).withValues(alpha: 0.7),
              fontSize: 16),
        ),
      ],
    );
  }

  Widget _controlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: _micOn ? 'Mute' : 'Unmute',
            active: !_micOn,
            onTap: _toggleMic,
          ),
          if (_isVideo)
            _CallButton(
              icon: _camOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: 'Camera',
              active: !_camOn,
              onTap: _toggleCam,
            )
          else
            _CallButton(
              icon: _speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.hearing_rounded,
              label: 'Speaker',
              active: _speakerOn,
              onTap: _toggleSpeaker,
            ),
          if (_isVideo)
            _CallButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              onTap: _switchCamera,
            ),
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'End',
            background: Colors.red,
            foreground: Colors.white,
            onTap: () => _hangUpLocally(),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (active ? Colors.white : Colors.white.withValues(alpha: 0.18));
    final fg = foreground ?? (active ? Colors.black : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
