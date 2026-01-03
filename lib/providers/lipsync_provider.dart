// lipsync_provider.dart
// Riverpod-based lip-sync state management with WFL backend polling
//
// Usage:
//   1. Add to pubspec.yaml:
//      flutter_riverpod: ^2.5.1
//      http: ^1.1.0
//      web_socket_channel: ^2.4.0  (optional, for WebSocket mode)
//
//   2. Wrap app with ProviderScope:
//      runApp(ProviderScope(child: MyApp()));
//
//   3. Drop MouthViewer() anywhere in your widget tree

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Viseme names matching your asset filenames
const visemeNames = [
  'neutral_closed', 'ah_open', 'ee_wide', 'oh', 'oo',
  'mp', 'kg', 'tn', 'v', 'breath'
];

// Map backend viseme IDs to indices
const visemeIndexMap = {
  'neutral_closed': 0,
  'ah_open': 1,
  'ee_wide': 2,
  'oh': 3,
  'oo': 4,
  'mp': 5,
  'kg': 6,
  'tn': 7,
  'v': 8,
  'breath': 9,
  // Rhubarb phoneme aliases
  'X': 0,
  'A': 1,
  'E': 2,
  'O': 3,
  'U': 4,
  'M': 5,
  'B': 5,
  'P': 5,
  'G': 6,
  'K': 6,
  'T': 7,
  'N': 7,
  'F': 8,
  'V': 8,
};

// Backend URL - override with ref.read(wflBaseUrlProvider.notifier).state = 'http://...'
final wflBaseUrlProvider = StateProvider<String>((ref) => 'http://localhost:3001');

// Polling interval - 40ms = 25fps, smooth for lip sync
final pollIntervalProvider = StateProvider<Duration>(
  (ref) => const Duration(milliseconds: 40)
);

// Main provider - polls WFL backend for active viseme
final mouthFrameProvider = StreamProvider<int>((ref) {
  final baseUrl = ref.watch(wflBaseUrlProvider);
  final interval = ref.watch(pollIntervalProvider);

  return Stream.periodic(interval)
      .asyncMap((_) => _getActiveMouthFrame(baseUrl));
});

Future<int> _getActiveMouthFrame(String baseUrl) async {
  try {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/render-sequence?frame=0')
    );
    if (resp.statusCode != 200) return 0;
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final visemeId = data['activeViseme'] ?? 'neutral_closed';
    return visemeIndexMap[visemeId] ?? 0;
  } catch (_) {
    return 0;
  }
}

// Main widget - drop anywhere in layout
class MouthViewer extends ConsumerWidget {
  final String character;
  final double width;
  final double height;
  final BoxFit fit;

  const MouthViewer({
    super.key,
    this.character = 'terry',
    this.width = 120,
    this.height = 80,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFrame = ref.watch(mouthFrameProvider);

    return asyncFrame.when(
      data: (idx) => Image.asset(
        'assets/$character/mouths/${visemeNames[idx]}.png',
        gaplessPlayback: true,
        width: width,
        height: height,
        fit: fit,
      ),
      loading: () => Image.asset(
        'assets/$character/mouths/neutral_closed.png',
        gaplessPlayback: true,
        width: width,
        height: height,
        fit: fit,
      ),
      error: (_, __) => SizedBox(width: width, height: height),
    );
  }
}

// ============================================
// WebSocket alternative (more efficient)
// ============================================
// Use mouthWsProvider instead of mouthFrameProvider
// for push-based updates (backend only sends when viseme changes)
//
// Add to pubspec.yaml: web_socket_channel: ^2.4.0

import 'package:web_socket_channel/web_socket_channel.dart';

final mouthWsProvider = StreamProvider<int>((ref) async* {
  final baseUrl = ref.watch(wflBaseUrlProvider);
  final wsUrl = baseUrl.replaceFirst('http', 'ws');

  final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));

  // Subscribe to viseme updates
  channel.sink.add(json.encode({'subscribe': 'viseme'}));

  await for (final raw in channel.stream) {
    final msg = json.decode(raw as String);

    // Initial connection sends current state
    if (msg['type'] == 'connected') {
      yield visemeIndexMap[msg['viseme']] ?? 0;
    }
    // Live updates
    else if (msg['type'] == 'viseme_update') {
      yield visemeIndexMap[msg['viseme']] ?? 0;
    }
  }

  channel.sink.close();
});

// ============================================
// Manual control provider (for testing/preview)
// ============================================
final manualVisemeProvider = StateProvider<int>((ref) => 0);

class ManualMouthViewer extends ConsumerWidget {
  final String character;
  final double width;
  final double height;

  const ManualMouthViewer({
    super.key,
    this.character = 'terry',
    this.width = 120,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(manualVisemeProvider);

    return Image.asset(
      'assets/$character/mouths/${visemeNames[idx]}.png',
      gaplessPlayback: true,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

// Test widget with viseme buttons
class MouthTester extends ConsumerWidget {
  final String character;

  const MouthTester({super.key, this.character = 'terry'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ManualMouthViewer(character: character, width: 200, height: 140),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(visemeNames.length, (i) {
            return ElevatedButton(
              onPressed: () => ref.read(manualVisemeProvider.notifier).state = i,
              child: Text(visemeNames[i].split('_').first),
            );
          }),
        ),
      ],
    );
  }
}
