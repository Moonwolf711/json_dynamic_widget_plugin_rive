import 'dart:async';
import 'package:flutter/material.dart';
import '../mouth_painter.dart';

/// Viseme names matching Rhubarb output → asset filenames
const kVisemeNames = [
  'x',        // 0: Closed/neutral
  'a',        // 1: Ah (father)
  'e',        // 2: Ee (bed)
  'i',        // 3: Ih (bit) - mapped to e
  'o',        // 4: Oh (go)
  'u',        // 5: Oo (boot)
  'm',        // 6: M/B/P (mat)
  'f',        // 7: F/V (oaf)
  'l',        // 8: L (loud)
];

/// Map Rhubarb phoneme letters to viseme index
const kPhonemeToViseme = {
  'X': 0, // neutral
  'A': 1, // ah
  'B': 6, // mbp
  'C': 2, // e
  'D': 1, // th -> ah
  'E': 2, // ee
  'F': 7, // fv
  'G': 4, // o
  'H': 5, // oo
};

/// Lip-sync mouth widget with smooth crossfade transitions
///
/// Supports two modes:
/// - PNG sprites: Uses Image.asset with crossfade
/// - Vector: Uses MouthPainter with animated path
///
/// Usage:
/// ```dart
/// LipsyncMouth(
///   character: 'terry',
///   visemeStream: myRhubarbStream,
///   mode: LipsyncMode.png,
///   crossfadeDuration: Duration(milliseconds: 50),
/// )
/// ```
class LipsyncMouth extends StatefulWidget {
  /// Character name for asset path (e.g., 'terry' -> assets/terry/mouths/)
  final String character;

  /// Stream of viseme indices (0-8) from Rhubarb or animation controller
  final Stream<int>? visemeStream;

  /// Stream of phoneme strings ('A'-'H', 'X') from Rhubarb
  final Stream<String>? phonemeStream;

  /// Initial viseme index
  final int initialViseme;

  /// Render mode: PNG sprites or vector paths
  final LipsyncMode mode;

  /// Duration of crossfade between visemes
  final Duration crossfadeDuration;

  /// Widget size
  final double width;
  final double height;

  /// Custom mouth color (vector mode only)
  final Color? mouthColor;

  /// Asset path template (PNG mode)
  /// Use {character} and {viseme} placeholders
  final String? assetPathTemplate;

  const LipsyncMouth({
    super.key,
    required this.character,
    this.visemeStream,
    this.phonemeStream,
    this.initialViseme = 0,
    this.mode = LipsyncMode.png,
    this.crossfadeDuration = const Duration(milliseconds: 40),
    this.width = 120,
    this.height = 80,
    this.mouthColor,
    this.assetPathTemplate,
  });

  @override
  State<LipsyncMouth> createState() => _LipsyncMouthState();
}

enum LipsyncMode { png, vector }

class _LipsyncMouthState extends State<LipsyncMouth>
    with SingleTickerProviderStateMixin {

  late int _currentViseme;
  late int _previousViseme;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  StreamSubscription<int>? _visemeSub;
  StreamSubscription<String>? _phonemeSub;

  @override
  void initState() {
    super.initState();
    _currentViseme = widget.initialViseme;
    _previousViseme = widget.initialViseme;

    _fadeController = AnimationController(
      vsync: this,
      duration: widget.crossfadeDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Subscribe to viseme stream
    if (widget.visemeStream != null) {
      _visemeSub = widget.visemeStream!.listen(_onVisemeChanged);
    }

    // Subscribe to phoneme stream
    if (widget.phonemeStream != null) {
      _phonemeSub = widget.phonemeStream!.listen(_onPhonemeChanged);
    }
  }

  @override
  void dispose() {
    _visemeSub?.cancel();
    _phonemeSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _onVisemeChanged(int viseme) {
    if (viseme != _currentViseme && viseme >= 0 && viseme < kVisemeNames.length) {
      setState(() {
        _previousViseme = _currentViseme;
        _currentViseme = viseme;
      });
      _fadeController.forward(from: 0);
    }
  }

  void _onPhonemeChanged(String phoneme) {
    final viseme = kPhonemeToViseme[phoneme.toUpperCase()] ?? 0;
    _onVisemeChanged(viseme);
  }

  /// Set viseme directly (for external control)
  void setViseme(int viseme) => _onVisemeChanged(viseme);

  /// Set phoneme directly
  void setPhoneme(String phoneme) => _onPhonemeChanged(phoneme);

  String get _assetPath {
    final template = widget.assetPathTemplate ??
        'assets/{character}/mouths/{viseme}.png';
    return template
        .replaceAll('{character}', widget.character)
        .replaceAll('{viseme}', kVisemeNames[_currentViseme]);
  }

  String get _previousAssetPath {
    final template = widget.assetPathTemplate ??
        'assets/{character}/mouths/{viseme}.png';
    return template
        .replaceAll('{character}', widget.character)
        .replaceAll('{viseme}', kVisemeNames[_previousViseme]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.mode == LipsyncMode.png
          ? _buildPngMouth()
          : _buildVectorMouth(),
    );
  }

  Widget _buildPngMouth() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Previous viseme (fading out)
            Opacity(
              opacity: 1.0 - _fadeAnimation.value,
              child: Image.asset(
                _previousAssetPath,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Current viseme (fading in)
            Opacity(
              opacity: _fadeAnimation.value,
              child: Image.asset(
                _assetPath,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _buildFallbackMouth(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVectorMouth() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        // For vector mode, we could lerp paths, but for now crossfade
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 1.0 - _fadeAnimation.value,
              child: MouthWidget(
                viseme: kVisemeNames[_previousViseme],
                width: widget.width,
                height: widget.height,
                mouthColor: widget.mouthColor,
              ),
            ),
            Opacity(
              opacity: _fadeAnimation.value,
              child: MouthWidget(
                viseme: kVisemeNames[_currentViseme],
                width: widget.width,
                height: widget.height,
                mouthColor: widget.mouthColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFallbackMouth() {
    // Fallback to vector if PNG missing
    return MouthWidget(
      viseme: kVisemeNames[_currentViseme],
      width: widget.width,
      height: widget.height,
      mouthColor: widget.mouthColor,
    );
  }
}

/// Simple lipsync controller for manual or Rhubarb-driven animation
class LipsyncController {
  final _visemeController = StreamController<int>.broadcast();
  final _phonemeController = StreamController<String>.broadcast();

  Stream<int> get visemeStream => _visemeController.stream;
  Stream<String> get phonemeStream => _phonemeController.stream;

  int _currentViseme = 0;
  int get currentViseme => _currentViseme;

  /// Set viseme by index (0-8)
  void setViseme(int viseme) {
    if (viseme >= 0 && viseme < kVisemeNames.length) {
      _currentViseme = viseme;
      _visemeController.add(viseme);
    }
  }

  /// Set viseme by Rhubarb phoneme ('A'-'H', 'X')
  void setPhoneme(String phoneme) {
    final viseme = kPhonemeToViseme[phoneme.toUpperCase()] ?? 0;
    setViseme(viseme);
    _phonemeController.add(phoneme);
  }

  /// Play Rhubarb frame data
  /// frames: List of {frame: int, phoneme: String} or {t: double, v: String}
  Future<void> playFrames(List<Map<String, dynamic>> frames, {
    int fps = 60,
    bool loop = false,
  }) async {
    final frameDuration = Duration(milliseconds: (1000 / fps).round());

    do {
      for (final frame in frames) {
        final phoneme = frame['phoneme'] ?? frame['v'] ?? 'X';
        setPhoneme(phoneme.toString());
        await Future.delayed(frameDuration);
      }
    } while (loop);
  }

  /// Play from Rhubarb JSON clip data
  Future<void> playClip(Map<String, dynamic> clipData, {bool loop = false}) async {
    final fps = clipData['fps'] ?? 60;
    final frames = (clipData['frames'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    await playFrames(frames, fps: fps, loop: loop);
  }

  void dispose() {
    _visemeController.close();
    _phonemeController.close();
  }
}

/// Convenience widget that creates its own controller
class LipsyncMouthAnimated extends StatefulWidget {
  final String character;
  final List<Map<String, dynamic>>? frames;
  final Map<String, dynamic>? clipData;
  final int fps;
  final bool autoPlay;
  final bool loop;
  final LipsyncMode mode;
  final double width;
  final double height;
  final Color? mouthColor;

  const LipsyncMouthAnimated({
    super.key,
    required this.character,
    this.frames,
    this.clipData,
    this.fps = 60,
    this.autoPlay = true,
    this.loop = false,
    this.mode = LipsyncMode.png,
    this.width = 120,
    this.height = 80,
    this.mouthColor,
  });

  @override
  State<LipsyncMouthAnimated> createState() => _LipsyncMouthAnimatedState();
}

class _LipsyncMouthAnimatedState extends State<LipsyncMouthAnimated> {
  late LipsyncController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LipsyncController();

    if (widget.autoPlay) {
      _startPlayback();
    }
  }

  void _startPlayback() async {
    if (widget.clipData != null) {
      await _controller.playClip(widget.clipData!, loop: widget.loop);
    } else if (widget.frames != null) {
      await _controller.playFrames(widget.frames!, fps: widget.fps, loop: widget.loop);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LipsyncMouth(
      character: widget.character,
      visemeStream: _controller.visemeStream,
      mode: widget.mode,
      width: widget.width,
      height: widget.height,
      mouthColor: widget.mouthColor,
    );
  }
}
