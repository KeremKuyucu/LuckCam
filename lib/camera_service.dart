import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CameraService {
  MediaStream? localStream;
  final RTCVideoRenderer renderer = RTCVideoRenderer();

  // StreamControllers
  final _microphoneStateStream = StreamController<bool>.broadcast();
  final _cameraSwitchedStream = StreamController<void>.broadcast();

  // Public Streams
  Stream<bool> get microphoneStateStream => _microphoneStateStream.stream;
  Stream<void> get cameraSwitchedStream => _cameraSwitchedStream.stream;

  bool _isMicrophoneMuted = false;
  bool _isFrontCamera = true;

  Future<void> initialize() async {
    await renderer.initialize();
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _disposeStream();

    final Map<String, dynamic> mediaConstraints = {
      'audio': !_isMicrophoneMuted,
      'video': {
        'facingMode': _isFrontCamera ? 'user' : 'environment',
        // 'width': 1280,
        // 'height': 720,
      },
    };

    try {
      // Yeni stream'i `getUserMedia` ile al
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      renderer.srcObject = localStream;
      _microphoneStateStream.add(_isMicrophoneMuted);
    } catch (e) {
      debugPrint("Kamera/Mikrofon erişim hatası: $e");
    }
  }

  void switchCamera() {
    if (localStream != null) {
      localStream!.getVideoTracks().forEach((track) => track.stop());
    }
    _isFrontCamera = !_isFrontCamera;
    _initializeCamera();
    _cameraSwitchedStream.add(null);
  }

  void toggleMicrophone() {
    _isMicrophoneMuted = !_isMicrophoneMuted;
    if (localStream != null) {
      localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMicrophoneMuted;
      });
    }
    _microphoneStateStream.add(_isMicrophoneMuted);
  }

  bool get isMicrophoneMuted => _isMicrophoneMuted;

  Future<void> _disposeStream() async {
    if (localStream != null) {
      localStream!.getTracks().forEach((track) async {
        await track.stop();
      });
      await localStream!.dispose();
      localStream = null;
    }
  }

  Future<void> dispose() async {
    await _disposeStream();
    await renderer.dispose();
    _microphoneStateStream.close();
    _cameraSwitchedStream.close();
  }
}
