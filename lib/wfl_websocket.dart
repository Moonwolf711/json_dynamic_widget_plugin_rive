import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for WFL Server communication
class WFLWebSocket {
  static const String _defaultUrl = 'ws://127.0.0.1:3000';

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  final String serverUrl;
  final void Function(String command, Map<String, dynamic> payload)? onCommand;
  final void Function(bool connected)? onConnectionChanged;

  WFLWebSocket({
    this.serverUrl = _defaultUrl,
    this.onCommand,
    this.onConnectionChanged,
  });

  bool get isConnected => _isConnected;

  /// Connect to the WFL server
  void connect() {
    if (_channel != null) return;

    _shouldReconnect = true;
    _attemptConnect();
  }

  void _attemptConnect() {
    try {
      debugPrint('WFL WebSocket: Connecting to $serverUrl...');

      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (error) {
          debugPrint('WFL WebSocket error: $error');
          _onDisconnected();
        },
      );

      // Mark connected after small delay (connection is async)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_channel != null) {
          _isConnected = true;
          onConnectionChanged?.call(true);
          debugPrint('WFL WebSocket: Connected!');
          _startPingTimer();
        }
      });

    } catch (e) {
      debugPrint('WFL WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data.toString()) as Map<String, dynamic>;

      // Handle pong from server
      if (msg['type'] == 'pong') {
        return;
      }

      // Extract command and pass to handler
      final command = msg['command'] as String?;
      if (command != null && onCommand != null) {
        onCommand!(command, msg);
      }

    } catch (e) {
      debugPrint('WFL WebSocket parse error: $e');
    }
  }

  void _onDisconnected() {
    debugPrint('WFL WebSocket: Disconnected');
    _isConnected = false;
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    onConnectionChanged?.call(false);

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect && _channel == null) {
        debugPrint('WFL WebSocket: Attempting reconnect...');
        _attemptConnect();
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      send({'type': 'ping'});
    });
  }

  /// Send a message to the server
  void send(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('WFL WebSocket send error: $e');
      }
    }
  }

  /// Send a status update back to server
  void sendStatus(String status, [Map<String, dynamic>? extra]) {
    send({
      'type': 'status',
      'status': status,
      ...?extra,
    });
  }

  /// Confirm preview is ready (sent after hot-reload completes)
  void sendPreviewReady(String asset, [String? character]) {
    send({
      'type': 'preview_ready',
      'asset': asset,
      'character': character,
      'status': 'ok',
    });
  }

  /// Confirm asset was loaded
  void sendAssetLoaded(String character, String layer, String asset) {
    send({
      'type': 'asset_loaded',
      'character': character,
      'layer': layer,
      'asset': asset,
      'status': 'ok',
    });
  }

  /// Disconnect from the server
  void disconnect() {
    _shouldReconnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
  }
}
