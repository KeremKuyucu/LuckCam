import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  HttpServer? _httpServer;
  WebSocketChannel? _connectedClient;

  final _serverUrlController = StreamController<String?>.broadcast();
  final _streamingStatusController = StreamController<bool>.broadcast();
  final _clientStatusController = StreamController<bool>.broadcast();

  Stream<String?> get serverUrlStream => _serverUrlController.stream;
  Stream<bool> get isStreamingStream => _streamingStatusController.stream;
  Stream<bool> get isClientConnectedStream => _clientStatusController.stream;

  static const int _serverPort = 2322;

  Future<void> startServer() async {
    if (_httpServer != null) return;
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip == null) {
        _serverUrlController.addError('Wi-Fi ağına bağlı değilsiniz.');
        return;
      }

      final handler = webSocketHandler((
        WebSocketChannel webSocket,
        String? protocol,
      ) {
        _handleWebSocketConnection(webSocket);
      });

      _httpServer = await shelf_io.serve(handler, ip, _serverPort);
      final serverUrl =
          'ws://${_httpServer!.address.host}:${_httpServer!.port}';
      _serverUrlController.add(serverUrl);
      print('✅ Sunucu başlatıldı: $serverUrl');
    } catch (e) {
      _serverUrlController.addError('Sunucu başlatılamadı: $e');
    }
  }

  void _handleWebSocketConnection(WebSocketChannel client) {
    print('✅ Bir izleyici bağlandı!');
    _connectedClient = client;
    _clientStatusController.add(true);

    client.stream.listen(
      (message) {
        final data = jsonDecode(message);
        print('⬇️ İzleyiciden mesaj alındı -> TÜR: ${data['type']}');
        if (data['type'] == 'answer') {
          _peerConnection?.setRemoteDescription(
            RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            ),
          );
        } else if (data['type'] == 'candidate') {
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate']['candidate'],
              data['candidate']['sdpMid'],
              data['candidate']['sdpMLineIndex'],
            ),
          );
        }
      },
      onDone: () {
        print('❌ İzleyici bağlantısı kesildi.');
        _connectedClient = null;
        _clientStatusController.add(false);
        stopStreaming();
      },
      onError: (error) {
        print('❌ İzleyici bağlantı hatası: $error');
        _connectedClient = null;
        _clientStatusController.add(false);
        stopStreaming();
      },
    );
  }

  Future<void> startStreaming(MediaStream stream) async {
    if (_connectedClient == null) {
      print("Yayın başlatılamadı: İzleyici bağlı değil.");
      return;
    }

    _localStream = stream;

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _sendToClient({'type': 'candidate', 'candidate': candidate.toMap()});
      }
    };

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    print('⬆️ Flutter -> Offer oluşturuldu ve gönderiliyor.');
    _sendToClient({'type': 'offer', 'offer': offer.toMap()});
    _streamingStatusController.add(true);
  }

  void _sendToClient(Map<String, dynamic> message) {
    if (_connectedClient != null) {
      _connectedClient!.sink.add(jsonEncode(message));
    }
  }

  Future<void> stopStreaming() async {
    try {
      _localStream?.getTracks().forEach((track) async {
        await track.stop();
      });
      await _localStream?.dispose();
      await _peerConnection?.close();
      _localStream = null;
      _peerConnection = null;
      _streamingStatusController.add(false);
      print('Yayın durduruldu.');
    } catch (e) {
      print('Yayın durdurma hatası: $e');
    }
  }

  Future<void> dispose() async {
    await stopStreaming();
    await _httpServer?.close(force: true);
    _connectedClient?.sink.close();
    _serverUrlController.close();
    _streamingStatusController.close();
    _clientStatusController.close();
  }
}
