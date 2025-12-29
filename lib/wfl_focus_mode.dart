import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

/// FOCUS MODE - Full-screen B-roll with Terry & Nigel overlay
/// Like a real show. Views go nuts.
class FullScreenBroll extends StatefulWidget {
  final String videoPath;
  final String? roastAudio;
  final String? roastText;
  final String character; // 'terry' or 'nigel'
  final VoidCallback? onExport;

  const FullScreenBroll({
    super.key,
    required this.videoPath,
    this.roastAudio,
    this.roastText,
    this.character = 'terry',
    this.onExport,
  });

  @override
  State<FullScreenBroll> createState() => _FullScreenBrollState();
}

class _FullScreenBrollState extends State<FullScreenBroll>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoPlayer;
  final AudioPlayer _voicePlayer = AudioPlayer();

  // Slide-in animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Lip-sync
  String _currentMouth = 'x';
  Timer? _lipSyncTimer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();

    // Video player - muted, full-screen
    _videoPlayer = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _videoPlayer.setLooping(true);
        _videoPlayer.setVolume(0); // Muted - roast audio plays over
        _videoPlayer.play();
        setState(() {});
      });

    // Slide-in animation (from right)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start off-screen right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Delay then slide in
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });

    // Play roast audio if provided
    if (widget.roastAudio != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _playRoast();
      });
    }
  }

  void _playRoast() async {
    if (widget.roastAudio != null) {
      await _voicePlayer.play(DeviceFileSource(widget.roastAudio!));

      // Start lip-sync from text
      if (widget.roastText != null) {
        _startLipSync(widget.roastText!);
      }
    }
  }

  void _startLipSync(String text) {
    _charIndex = 0;
    _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_charIndex >= text.length) {
        timer.cancel();
        setState(() => _currentMouth = 'x');
        return;
      }

      final char = text[_charIndex].toLowerCase();
      String mouth = 'x';

      if ('aáà'.contains(char)) {
        mouth = 'a';
      } else if ('eéè'.contains(char)) {
        mouth = 'e';
      } else if ('iíì'.contains(char)) {
        mouth = 'i';
      } else if ('oóò'.contains(char)) {
        mouth = 'o';
      } else if ('uúù'.contains(char)) {
        mouth = 'u';
      } else if ('fv'.contains(char)) {
        mouth = 'f';
      } else if ('mbp'.contains(char)) {
        mouth = 'm';
      }

      setState(() => _currentMouth = mouth);
      _charIndex++;
    });
  }

  @override
  void dispose() {
    _videoPlayer.dispose();
    _voicePlayer.dispose();
    _slideController.dispose();
    _lipSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FULL BACKGROUND VIDEO
          if (_videoPlayer.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoPlayer.value.aspectRatio,
                child: VideoPlayer(_videoPlayer),
              ),
            ),

          // 2. CHARACTERS OVERLAY (bottom-right, scaled 0.85)
          Positioned(
            bottom: 20,
            right: 20,
            child: SlideTransition(
              position: _slideAnimation,
              child: Transform.scale(
                scale: 0.85,
                alignment: Alignment.bottomRight,
                child: _buildCharacterOverlay(),
              ),
            ),
          ),

          // 3. ROAST TEXT (if available)
          if (widget.roastText != null)
            Positioned(
              bottom: 200,
              left: 40,
              right: 200,
              child: _buildRoastCaption(),
            ),

          // 4. TOP BAR - Exit + Export
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // 5. FOCUS MODE BADGE
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha:0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'ZOOM ROAST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterOverlay() {
    final name = widget.character;
    return Container(
      width: 250,
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.5),
            blurRadius: 20,
            offset: const Offset(-5, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Character body
            Positioned.fill(
              child: Image.asset(
                'assets/characters/$name/layers/layer_01_body.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Text('👽', style: TextStyle(fontSize: 80)),
                  ),
                ),
              ),
            ),

            // Mouth overlay
            Positioned(
              left: 60,
              top: 120,
              child: Image.asset(
                'assets/characters/$name/mouth_shapes/$_currentMouth.png',
                width: 100,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoastCaption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '"${widget.roastText}"',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha:0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const Spacer(),

            // Export button
            ElevatedButton.icon(
              onPressed: () {
                widget.onExport?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exporting Zoom Roast...')),
                );
              },
              icon: const Icon(Icons.movie, size: 18),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
