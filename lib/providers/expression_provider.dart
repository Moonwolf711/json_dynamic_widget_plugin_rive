// expression_provider.dart
// WFL Proprietary Expression State Provider v1.0
// Copyright (c) 2024 Wooking For Love Project - All Rights Reserved
//
// Receives full 27-point expression rig state from server at 60fps

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Server URL
final expressionServerUrlProvider = StateProvider<String>(
  (ref) => 'ws://localhost:3001/ws'
);

// Full expression frame from server
class ExpressionFrame {
  final int frame;
  final String emotion;
  final String viseme;
  final double blinkPhase;
  final Map<String, double> rig;
  final int timestamp;

  const ExpressionFrame({
    this.frame = 0,
    this.emotion = 'neutral',
    this.viseme = 'X',
    this.blinkPhase = 0,
    this.rig = const {},
    this.timestamp = 0,
  });

  factory ExpressionFrame.fromJson(Map<String, dynamic> json) {
    final rigData = json['rig'] as Map<String, dynamic>? ?? {};
    return ExpressionFrame(
      frame: json['frame'] as int? ?? 0,
      emotion: json['emotion'] as String? ?? 'neutral',
      viseme: json['viseme'] as String? ?? 'X',
      blinkPhase: (json['blinkPhase'] as num?)?.toDouble() ?? 0,
      rig: rigData.map((k, v) => MapEntry(k, (v as num).toDouble())),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  // Convenience getters for common rig values
  double get browLeftMid => rig['brow_l_mid'] ?? 0;
  double get browRightMid => rig['brow_r_mid'] ?? 0;
  double get browLeftIn => rig['brow_l_in'] ?? 0;
  double get browRightIn => rig['brow_r_in'] ?? 0;
  double get browLeftOut => rig['brow_l_out'] ?? 0;
  double get browRightOut => rig['brow_r_out'] ?? 0;

  double get lidLeftUp => rig['lid_l_up'] ?? 0;
  double get lidRightUp => rig['lid_r_up'] ?? 0;
  double get lidLeftLow => rig['lid_l_low'] ?? 0;
  double get lidRightLow => rig['lid_r_low'] ?? 0;

  double get pupilLeftX => rig['pupil_l_x'] ?? 0;
  double get pupilLeftY => rig['pupil_l_y'] ?? 0;
  double get pupilRightX => rig['pupil_r_x'] ?? 0;
  double get pupilRightY => rig['pupil_r_y'] ?? 0;
  double get pupilDilation => rig['pupil_dil'] ?? 0;

  double get cheekLeft => rig['cheek_l'] ?? 0;
  double get cheekRight => rig['cheek_r'] ?? 0;

  double get nostrilLeft => rig['nostril_l'] ?? 0;
  double get nostrilRight => rig['nostril_r'] ?? 0;

  double get mouthLeft => rig['mouth_l'] ?? 0;
  double get mouthRight => rig['mouth_r'] ?? 0;
  double get mouthStretch => rig['mouth_stretch'] ?? 0;

  double get headYaw => rig['head_yaw'] ?? 0;
  double get headPitch => rig['head_pitch'] ?? 0;
  double get headRoll => rig['head_roll'] ?? 0;

  // Derived values
  double get browLeftY => browLeftMid * 15;
  double get browRightY => browRightMid * 15;
  double get headYawDegrees => headYaw * 30;
  double get headPitchDegrees => headPitch * 20;
  double get headRollDegrees => headRoll * 15;
}

// Main expression stream provider
final expressionFrameProvider = StreamProvider<ExpressionFrame>((ref) async* {
  final url = ref.watch(expressionServerUrlProvider);

  WebSocketChannel? channel;

  try {
    channel = WebSocketChannel.connect(Uri.parse(url));

    await for (final raw in channel.stream) {
      try {
        final data = json.decode(raw as String) as Map<String, dynamic>;

        if (data['type'] == 'expression_frame') {
          yield ExpressionFrame.fromJson(data);
        } else if (data['type'] == 'connected') {
          // Initial connection - emit neutral frame
          yield const ExpressionFrame();
        }
      } catch (e) {
        // Skip malformed frames
      }
    }
  } finally {
    channel?.sink.close();
  }
});

// Individual aspect providers for targeted rebuilds
final currentEmotionProvider = Provider<String>((ref) {
  return ref.watch(expressionFrameProvider).whenData((f) => f.emotion).value ?? 'neutral';
});

final currentVisemeProvider = Provider<String>((ref) {
  return ref.watch(expressionFrameProvider).whenData((f) => f.viseme).value ?? 'X';
});

final blinkPhaseProvider = Provider<double>((ref) {
  return ref.watch(expressionFrameProvider).whenData((f) => f.blinkPhase).value ?? 0;
});

final gazePositionProvider = Provider<({double x, double y})>((ref) {
  final frame = ref.watch(expressionFrameProvider).value;
  return (x: frame?.pupilLeftX ?? 0, y: frame?.pupilLeftY ?? 0);
});

final headRotationProvider = Provider<({double yaw, double pitch, double roll})>((ref) {
  final frame = ref.watch(expressionFrameProvider).value;
  return (
    yaw: frame?.headYawDegrees ?? 0,
    pitch: frame?.headPitchDegrees ?? 0,
    roll: frame?.headRollDegrees ?? 0,
  );
});

// WebSocket command sender
class ExpressionCommands {
  final WebSocketChannel channel;

  ExpressionCommands(String url)
      : channel = WebSocketChannel.connect(Uri.parse(url));

  void setEmotion(String emotion) {
    channel.sink.add(json.encode({'setEmotion': emotion}));
  }

  void triggerBlink() {
    channel.sink.add(json.encode({'triggerBlink': true}));
  }

  void lookAt(double x, double y) {
    channel.sink.add(json.encode({'lookAt': {'x': x, 'y': y}}));
  }

  void dispose() {
    channel.sink.close();
  }
}

// Command provider
final expressionCommandsProvider = Provider<ExpressionCommands>((ref) {
  final url = ref.watch(expressionServerUrlProvider);
  final commands = ExpressionCommands(url);
  ref.onDispose(() => commands.dispose());
  return commands;
});

// Viseme index mapping
const visemeIndexMap = {
  'X': 0, 'A': 1, 'B': 5, 'C': 2, 'D': 1, 'E': 2, 'F': 8, 'G': 3, 'H': 4,
  'neutral_closed': 0, 'ah_open': 1, 'ee_wide': 2, 'oh': 3, 'oo': 4,
  'mp': 5, 'kg': 6, 'tn': 7, 'v': 8, 'breath': 9,
};

final visemeIndexProvider = Provider<int>((ref) {
  final viseme = ref.watch(currentVisemeProvider);
  return visemeIndexMap[viseme] ?? 0;
});
