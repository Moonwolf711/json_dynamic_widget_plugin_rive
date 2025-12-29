// WebSocket controller for Node.js server communication
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'wfl_config.dart';

/// Commands that can be received from Node.js server
enum NodeCommand {
  play,
  roast,
  lip,
  head,
  pupil,
  talk,
  warp,
  export,
  navigate,
  update,
}

/// Controller for WebSocket communication with Node.js server
class NodeController {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onCommand;
  bool _connected = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // Default to localhost - change for mobile/USB debugging
  // Use your machine's IP like 'ws://192.168.1.100:3000' for phone testing
  String _serverUrl = 'ws://localhost:3000';

  static const _heartbeatInterval = Duration(seconds: 30);
  static const _reconnectDelay = Duration(seconds: 5);

  bool get isConnected => _connected;
  String get serverUrl => _serverUrl;

  /// Connect to Node.js WebSocket server
  /// For mobile/USB debugging, pass your machine's IP:
  /// controller.connect(url: 'ws://192.168.1.100:3000');
  Future<void> connect({String? url}) async {
    if (url != null) _serverUrl = url;

    final uri = Uri.parse(_serverUrl);
    final token = WFLConfig.controlToken;
    final effectiveUri =
        (token.isNotEmpty && !uri.queryParameters.containsKey('token'))
            ? uri.replace(queryParameters: {
                ...uri.queryParameters,
                'token': token,
              })
            : uri;

    debugPrint('NodeController: Connecting to $effectiveUri...');

    try {
      _channel = WebSocketChannel.connect(effectiveUri);

      // Wait for connection to be ready
      await _channel!.ready.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('NodeController: Stream error: $error');
          _connected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('NodeController: WebSocket closed');
          _connected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        },
      );

      _connected = true;
      _reconnectTimer?.cancel(); // Stop any pending reconnect attempts
      _startHeartbeat();
      debugPrint('NodeController: Connected to $_serverUrl');
    } catch (e) {
      debugPrint('NodeController: Server not available - running offline');
      _connected = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      debugPrint('NodeController: Attempting to reconnect...');
      connect();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_connected) {
        send({'type': 'ping'});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      // Handle pong response (heartbeat ack)
      if (data['type'] == 'pong') {
        return;
      }
      debugPrint('NodeController: Received command: ${data['command']}');
      onCommand?.call(data);
    } catch (e) {
      debugPrint('NodeController: Failed to parse message: $e');
    }
  }

  /// Send data back to Node.js server
  void send(Map<String, dynamic> data) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Send status update to server
  void sendStatus(String status, [Map<String, dynamic>? extra]) {
    send({
      'type': 'status',
      'status': status,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...?extra,
    });
  }

  /// Disconnect from server
  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    debugPrint('NodeController: Disconnected');
  }

  /// Reconnect to server
  void reconnect() {
    disconnect();
    connect();
  }
}
