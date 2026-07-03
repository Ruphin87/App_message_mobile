import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/call_model.dart';
import '../controllers/call_controller.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.callId,
    required this.args,
  });

  final String callId;
  final CallRouteArgs args;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final Set<String> _handledEventIds = {};
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<List<CallEventModel>>? _eventsSubscription;
  StreamSubscription<CallModel?>? _callSubscription;

  bool _isReady = false;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _hasRemoteDescription = false;
  String? _statusText;

  bool get _isVideoCall => widget.args.mediaType == CallMediaType.video;

  @override
  void initState() {
    super.initState();
    _statusText = widget.args.isCaller ? 'Appel en cours...' : 'Connexion...';
    _setupCall();
  }

  Future<void> _setupCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final hasPermissions = await _ensureCallPermissions();
      if (!hasPermissions) {
        if (!mounted) return;
        setState(() => _statusText = 'Permissions requises');
        return;
      }

      await _openLocalMedia();
      await _createPeerConnection();
      _listenCallStatus();
      _listenSignalEvents();

      if (widget.args.isCaller) {
        await _createOffer();
      } else {
        await ref.read(callRepositoryProvider).acceptCall(widget.callId);
      }

      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusText = 'Impossible de démarrer l\'appel');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérifiez les permissions micro/caméra.')),
      );
    }
  }

  Future<bool> _ensureCallPermissions() async {
    final permissions = <Permission>[
      Permission.microphone,
      if (_isVideoCall) Permission.camera,
    ];

    final statuses = await permissions.request();
    final denied = statuses.entries.where((entry) {
      final status = entry.value;
      return status.isDenied || status.isPermanentlyDenied || status.isRestricted;
    }).toList();

    if (denied.isNotEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVideoCall
                ? 'Autorisez le micro et la caméra pour démarrer l’appel vidéo.'
                : 'Autorisez le micro pour démarrer l’appel audio.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _openLocalMedia() async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': _isVideoCall
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localRenderer.srcObject = _localStream;
  }

  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    final pc = await createPeerConnection(configuration);
    _peerConnection = pc;

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      ref.read(callRepositoryProvider).sendCallEvent(
        callId: widget.callId,
        eventType: 'candidate',
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remoteRenderer.srcObject = event.streams.first;
      if (mounted) {
        setState(() {
          _isConnected = true;
          _statusText = 'Connecté';
        });
      }
    };

    pc.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() {
          _isConnected = true;
          _statusText = 'Connecté';
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        setState(() => _statusText = 'Appel terminé');
      }
    };
  }

  Future<void> _createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await ref.read(callRepositoryProvider).sendCallEvent(
      callId: widget.callId,
      eventType: 'offer',
      payload: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  Future<void> _createAnswer(RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    _hasRemoteDescription = true;
    await _flushPendingCandidates();

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await ref.read(callRepositoryProvider).sendCallEvent(
      callId: widget.callId,
      eventType: 'answer',
      payload: {'sdp': answer.sdp, 'type': answer.type},
    );
  }

  void _listenSignalEvents() {
    final currentUserId = ref.read(callRepositoryProvider).currentUserId;
    _eventsSubscription = ref
        .read(callRepositoryProvider)
        .watchCallEvents(widget.callId)
        .listen((events) async {
      for (final event in events) {
        if (_handledEventIds.contains(event.id) || event.senderId == currentUserId) {
          continue;
        }
        _handledEventIds.add(event.id);
        await _handleSignalEvent(event);
      }
    });
  }

  Future<void> _handleSignalEvent(CallEventModel event) async {
    final pc = _peerConnection;
    if (pc == null) return;

    if (event.eventType == 'offer' && !widget.args.isCaller) {
      final offer = RTCSessionDescription(
        event.payload['sdp'] as String?,
        event.payload['type'] as String?,
      );
      await _createAnswer(offer);
      return;
    }

    if (event.eventType == 'answer' && widget.args.isCaller) {
      final answer = RTCSessionDescription(
        event.payload['sdp'] as String?,
        event.payload['type'] as String?,
      );
      await pc.setRemoteDescription(answer);
      _hasRemoteDescription = true;
      await _flushPendingCandidates();
      return;
    }

    if (event.eventType == 'candidate') {
      final candidate = RTCIceCandidate(
        event.payload['candidate'] as String?,
        event.payload['sdpMid'] as String?,
        event.payload['sdpMLineIndex'] as int?,
      );
      if (_hasRemoteDescription) {
        await pc.addCandidate(candidate);
      } else {
        _pendingRemoteCandidates.add(candidate);
      }
    }
  }

  Future<void> _flushPendingCandidates() async {
    final pc = _peerConnection;
    if (pc == null) return;

    for (final candidate in _pendingRemoteCandidates) {
      await pc.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  void _listenCallStatus() {
    _callSubscription = ref.read(callRepositoryProvider).watchCall(widget.callId).listen((call) {
      if (!mounted) return;
      if (call == null) {
        setState(() => _statusText = 'Appel terminé');
        _closeAfterDelay();
        return;
      }
      if (call.status == CallStatus.declined) {
        setState(() => _statusText = 'Appel refusé');
        _closeAfterDelay();
      } else if (call.status == CallStatus.ended || call.status == CallStatus.missed) {
        setState(() => _statusText = 'Appel terminé');
        _closeAfterDelay();
      } else if (call.status == CallStatus.accepted) {
        setState(() => _statusText = _isConnected ? 'Connecté' : 'Connexion...');
      }
    });
  }

  void _closeAfterDelay() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && context.canPop()) context.pop();
    });
  }

  void _toggleMicrophone() {
    final audioTracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    for (final track in audioTracks) {
      track.enabled = _isMuted;
    }
    HapticFeedback.selectionClick();
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleCamera() {
    final videoTracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    for (final track in videoTracks) {
      track.enabled = _isCameraOff;
    }
    HapticFeedback.selectionClick();
    setState(() => _isCameraOff = !_isCameraOff);
  }

  Future<void> _switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks.first);
  }

  Future<void> _endCall() async {
    try {
      await ref.read(callRepositoryProvider).endCall(widget.callId);
    } catch (_) {
      // La fermeture locale reste prioritaire si le réseau coupe au même moment.
    }
    if (mounted && context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _callSubscription?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _isVideoCall ? _buildVideoStage() : _buildAudioStage(),
              ),
              Positioned(
                left: 16,
                top: 16,
                right: 16,
                child: _buildHeader(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _remoteRenderer.srcObject != null
            ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : _buildWaitingSurface(),
        Positioned(
          right: 16,
          top: 96,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 118,
              height: 164,
              color: AppColors.textPrimary,
              child: _isCameraOff
                  ? const Icon(Icons.videocam_off, color: Colors.white)
                  : RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioStage() {
    return _buildWaitingSurface();
  }

  Widget _buildWaitingSurface() {
    return Container(
      color: AppColors.textPrimary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UserAvatar(
            userId: widget.args.otherUserId,
            photoUrl: widget.args.otherUserPhoto,
            radius: 56,
          ),
          const SizedBox(height: 20),
          Text(
            widget.args.otherUserName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusText ?? (_isReady ? 'Connexion...' : 'Préparation...'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _endCall,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _isVideoCall ? 'Appel vidéo' : 'Appel audio',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CallControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          onPressed: _toggleMicrophone,
          backgroundColor: Colors.white.withValues(alpha: 0.16),
        ),
        if (_isVideoCall) ...[
          const SizedBox(width: 14),
          _CallControlButton(
            icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
            onPressed: _toggleCamera,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
          ),
          const SizedBox(width: 14),
          _CallControlButton(
            icon: Icons.cameraswitch,
            onPressed: _switchCamera,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
          ),
        ],
        const SizedBox(width: 14),
        _CallControlButton(
          icon: Icons.call_end,
          onPressed: _endCall,
          backgroundColor: AppColors.error,
          size: 64,
        ),
      ],
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    this.size = 54,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon),
      ),
    );
  }
}
