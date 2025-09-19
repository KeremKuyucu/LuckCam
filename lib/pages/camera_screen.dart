import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:luckcam/services/camera_service.dart';
import 'package:luckcam/services/webrtc_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraService _cameraService;
  late final WebRTCService _webrtcService;

  String? _serverUrl;
  bool _isClientConnected = false;
  bool _isStreaming = false;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _webrtcService = WebRTCService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _cameraService.initialize();
    setState(() {
      _isCameraInitialized = true;
    });

    await _webrtcService.startServer();

    _webrtcService.serverUrlStream.listen(
      (url) => setState(() => _serverUrl = url),
    );

    _webrtcService.isClientConnectedStream.listen((isConnected) {
      setState(() => _isClientConnected = isConnected);

      if (isConnected && !_isStreaming && _cameraService.localStream != null) {
        _webrtcService.startStreaming(_cameraService.localStream!);
      } else if (!isConnected && _isStreaming) {
        _webrtcService.stopStreaming();
      }
    });

    _webrtcService.isStreamingStream.listen(
      (isStreaming) => setState(() => _isStreaming = isStreaming),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: !_isCameraInitialized
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  _buildCameraPreview(),
                  _buildControls(),
                  _buildServerInfo(),
                ],
              ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: RTCVideoView(_cameraService.renderer),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, size: 30),
                onPressed: _cameraService.switchCamera,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              StreamBuilder<bool>(
                stream: _cameraService.microphoneStateStream,
                initialData: _cameraService.isMicrophoneMuted,
                builder: (context, snapshot) {
                  final isMuted = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isMuted ? Icons.mic_off : Icons.mic, size: 30),
                    onPressed: _cameraService.toggleMicrophone,
                    color: isMuted ? Colors.red : Colors.white,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerInfo() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "PC'den Bağlanmak İçin:",
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  _serverUrl?.replaceFirst('ws://', '') ??
                      'Sunucu başlatılıyor...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isClientConnected
                    ? (_isStreaming ? Colors.green : Colors.blue)
                    : Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isClientConnected
                    ? (_isStreaming ? "YAYINDA" : "BAĞLI")
                    : "BEKLENİYOR",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
