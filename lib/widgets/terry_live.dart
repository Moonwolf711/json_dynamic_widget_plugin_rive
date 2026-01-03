// terry_live.dart
// Full animated Terry character widget - lip-sync, blink, head sway, arm sway
//
// Usage: Drop <TerryLive/> anywhere in your widget tree
// Requires: ProviderScope at app root, WebSocket backend broadcasting frames

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/terry_live_provider.dart';

class TerryLive extends ConsumerWidget {
  final double scale;
  final bool showDebug;

  const TerryLive({
    super.key,
    this.scale = 1.0,
    this.showDebug = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(animationProvider);

    return asyncState.when(
      data: (s) => _buildAnimatedTerry(s),
      loading: () => _buildStaticTerry(),
      error: (e, _) => _buildErrorState(e),
    );
  }

  Widget _buildAnimatedTerry(AnimationState s) {
    return Transform.scale(
      scale: scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer 0: Body (static base)
          Image.asset(
            'assets/terry/body.png',
            gaplessPlayback: true,
          ),

          // Layer 1: Right arm (rotates at shoulder for idle sway)
          Positioned(
            right: 20,
            top: 180,
            child: Transform.rotate(
              angle: s.armRotRad,
              alignment: Alignment.topCenter, // Pivot at shoulder
              child: Image.asset(
                'assets/terry/arm_right.png',
                gaplessPlayback: true,
              ),
            ),
          ),

          // Layer 2: Left arm (slight counter-sway)
          Positioned(
            left: 20,
            top: 180,
            child: Transform.rotate(
              angle: -s.armRotRad * 0.5, // Subtle counter-motion
              alignment: Alignment.topCenter,
              child: Image.asset(
                'assets/terry/arm_left.png',
                gaplessPlayback: true,
              ),
            ),
          ),

          // Layer 3: Head group (rotates + bobs for breathing)
          Positioned(
            top: 20,
            child: Transform.translate(
              offset: Offset(0, s.headY),
              child: Transform.rotate(
                angle: s.headRotRad,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Base head
                    Image.asset(
                      'assets/terry/head.png',
                      gaplessPlayback: true,
                    ),

                    // Mouth (lip-sync)
                    Positioned(
                      bottom: 40,
                      child: Image.asset(
                        'assets/characters/terry/mouth_shapes/${visemeNames[s.visemeIdx]}.png',
                        gaplessPlayback: true,
                        width: 80,
                        height: 50,
                      ),
                    ),

                    // Eyes - crossfade between open/closed
                    Positioned(
                      top: 60,
                      child: Stack(
                        children: [
                          // Eyes open (fades out when blinking)
                          AnimatedOpacity(
                            opacity: s.eyesClosed ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 50),
                            child: Image.asset(
                              'assets/terry/eyes_open.png',
                              gaplessPlayback: true,
                            ),
                          ),
                          // Eyes closed (fades in when blinking)
                          AnimatedOpacity(
                            opacity: s.eyesClosed ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 50),
                            child: Image.asset(
                              'assets/terry/eyes_closed.png',
                              gaplessPlayback: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Emotion overlay (optional expressions)
                    if (s.emotion != 'chill')
                      Positioned(
                        top: 40,
                        child: Image.asset(
                          'assets/terry/emotions/${s.emotion}.png',
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Debug overlay
          if (showDebug)
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  'Frame: ${s.frame}\n'
                  'Viseme: ${visemeNames[s.visemeIdx]}\n'
                  'Blink: ${s.eyesClosed}\n'
                  'Head: ${s.headRot.toStringAsFixed(1)}° / ${s.headY.toStringAsFixed(1)}px\n'
                  'Arm: ${s.armRot.toStringAsFixed(1)}°\n'
                  'Emotion: ${s.emotion}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaticTerry() {
    return Transform.scale(
      scale: scale,
      child: Image.asset(
        'assets/terry/full_neutral.png',
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No connection',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// Simplified version - just mouth and blink, no transforms
class TerryLiveSimple extends ConsumerWidget {
  final String character;
  final double width;
  final double height;

  const TerryLiveSimple({
    super.key,
    this.character = 'terry',
    this.width = 300,
    this.height = 400,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(animationProvider);

    return SizedBox(
      width: width,
      height: height,
      child: asyncState.when(
        data: (s) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/$character/base.png',
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            Image.asset(
              'assets/$character/mouths/${visemeNames[s.visemeIdx]}.png',
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            AnimatedOpacity(
              opacity: s.eyesClosed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 50),
              child: Image.asset(
                'assets/$character/eyes_closed.png',
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Icon(Icons.error)),
      ),
    );
  }
}
