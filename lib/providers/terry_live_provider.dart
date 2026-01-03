// terry_live_provider.dart
// Full character animation state over WebSocket - 60fps, zero polling
//
// Provides: lip-sync, blink, head sway, arm sway, emotion
// Add to pubspec.yaml:
//   flutter_riverpod: ^2.5.1
//   web_socket_channel: ^2.4.0

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Viseme index mapping
const visemeIndexMap = {
  'neutral_closed': 0, 'ah_open': 1, 'ee_wide': 2,
  'oh': 3, 'oo': 4, 'mp': 5, 'kg': 6, 'tn': 7, 'v': 8, 'breath': 9,
  'X': 0, 'A': 1, 'E': 2, 'O': 3, 'U': 4, 'M': 5, 'B': 5, 'P': 5,
  'G': 6, 'K': 6, 'T': 7, 'N': 7, 'F': 8, 'V': 8,
};

const visemeNames = [
  'neutral_closed', 'ah_open', 'ee_wide', 'oh', 'oo',
  'mp', 'kg', 'tn', 'v', 'breath'
];

// Backend URL provider
final wsUrlProvider = StateProvider<String>((ref) => 'ws://localhost:3001/ws');

// Full animation state from backend
class AnimationState {
  final int visemeIdx;
  final bool eyesClosed;
  final double headRot;    // degrees
  final double headY;      // pixels (breathing/bounce)
  final double armRot;     // degrees (idle sway)
  final String emotion;    // 'chill', 'happy', 'angry', etc.
  final int frame;

  const AnimationState({
    this.visemeIdx = 0,
    this.eyesClosed = false,
    this.headRot = 0,
    this.headY = 0,
    this.armRot = 0,
    this.emotion = 'chill',
    this.frame = 0,
  });

  factory AnimationState.fromJson(Map<String, dynamic> j) {
    final head = j['head'] as Map<String, dynamic>? ?? {};
    final armR = j['armR'] as Map<String, dynamic>? ?? {};

    return AnimationState(
      visemeIdx: visemeIndexMap[j['viseme']] ?? 0,
      eyesClosed: j['blink'] == 'closed',
      headRot: (head['rot'] as num?)?.toDouble() ?? 0,
      headY: (head['y'] as num?)?.toDouble() ?? 0,
      armRot: (armR['rot'] as num?)?.toDouble() ?? 0,
      emotion: j['emotion'] as String? ?? 'chill',
      frame: j['frame'] as int? ?? 0,
    );
  }

  // Degrees to radians helper
  double get headRotRad => headRot * math.pi / 180;
  double get armRotRad => armRot * math.pi / 180;
}

// Main animation provider - receives full state at 60fps
final animationProvider = StreamProvider<AnimationState>((ref) async* {
  final wsUrl = ref.watch(wsUrlProvider);
  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  // Send subscription
  channel.sink.add(json.encode({'subscribe': 'animation'}));

  await for (final raw in channel.stream) {
    try {
      final data = json.decode(raw as String) as Map<String, dynamic>;
      if (data['type'] == 'frame') {
        yield AnimationState.fromJson(data);
      } else if (data['type'] == 'connected') {
        // Initial state
        yield const AnimationState();
      }
    } catch (e) {
      // Skip malformed frames
    }
  }

  channel.sink.close();
});

// Individual state selectors (for widgets that only need one thing)
final visemeProvider = Provider<int>((ref) {
  return ref.watch(animationProvider).whenData((s) => s.visemeIdx).value ?? 0;
});

final blinkProvider = Provider<bool>((ref) {
  return ref.watch(animationProvider).whenData((s) => s.eyesClosed).value ?? false;
});

final headTransformProvider = Provider<({double rot, double y})>((ref) {
  final state = ref.watch(animationProvider).value;
  return (rot: state?.headRot ?? 0, y: state?.headY ?? 0);
});

final emotionProvider = Provider<String>((ref) {
  return ref.watch(animationProvider).whenData((s) => s.emotion).value ?? 'chill';
});
