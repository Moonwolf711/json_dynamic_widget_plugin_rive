// terry_live_viewer.dart — Pure Dart TCP viewer (zero packages)
// 60fps animation with smooth blinks, gaze follow, idle fidgets

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

/// Terry Live Viewer — real-time animation with organic details
class TerryLiveViewer extends StatefulWidget {
  final String host;
  final int port;
  final String assetPath;

  const TerryLiveViewer({
    super.key,
    this.host = 'localhost',
    this.port = 3001,
    this.assetPath = 'assets/characters/terry',
  });

  @override
  State<TerryLiveViewer> createState() => _TerryLiveViewerState();
}

class _TerryLiveViewerState extends State<TerryLiveViewer>
    with TickerProviderStateMixin {
  Socket? _socket;
  bool _connected = false;
  String _error = '';

  // Animation state from server
  int _frame = 0;
  int _visemeIndex = 0;
  bool _eyesClosed = false;
  double _headRot = 0;
  double _headY = 0;
  double _armAngle = 0;
  double _prevArmAngle = 0; // For motion blur
  String _emotion = 'chill';
  String _currentViseme = 'neutral_closed';

  // Gaze follow (cursor tracking)
  double _gazeX = 0; // -3 to +3 degrees
  double _gazeY = 0;
  Offset? _lastCursorPos;

  // Idle fidget state
  int _fidgetFrame = 0;
  bool _isFidgeting = false;
  String _fidgetType = 'scratch'; // 'scratch' or 'chain'
  Timer? _fidgetTimer;
  Timer? _fidgetFrameTimer;

  // Blink animation controller for extra smoothness
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _wasEyesClosed = false;

  // Breathing animation — soft pulse on chest
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  // Chain sparkle — medallion glow
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  static const _visemeToFile = {
    'neutral_closed': 'x',
    'ah_open': 'a',
    'ee_wide': 'e',
    'oh': 'o',
    'oo': 'u',
    'mp': 'm',
    'kg': 'a',
    'tn': 'l',
    'fv': 'f',
    'breath': 'x',
  };

  @override
  void initState() {
    super.initState();

    // Smooth blink animation
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );
    _blinkAnimation = CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeOutCubic,
    );

    // Breathing animation — 3 second cycle, synced with head bob
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Chain sparkle — 500ms pulse
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _sparkleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );

    _connect();
    _startIdleFidgets();
  }

  @override
  void dispose() {
    _socket?.close();
    _fidgetTimer?.cancel();
    _fidgetFrameTimer?.cancel();
    _blinkController.dispose();
    _breathController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  // ============================================
  // Idle Fidgets — scratch dreads, adjust chain
  // ============================================

  void _startIdleFidgets() {
    // Every 8-12 seconds, do a fidget
    _scheduleFidget();
  }

  void _scheduleFidget() {
    final delay = 8 + Random().nextInt(4); // 8-12 seconds
    _fidgetTimer = Timer(Duration(seconds: delay), () {
      if (mounted) {
        _doFidget();
        _scheduleFidget(); // Schedule next
      }
    });
  }

  void _doFidget() {
    if (_isFidgeting) return;

    setState(() {
      _isFidgeting = true;
      _fidgetFrame = 0;
      _fidgetType = Random().nextBool() ? 'scratch' : 'chain';
    });

    // Play 4 frames at 5fps (200ms per frame)
    _fidgetFrameTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _fidgetFrame++;
        if (_fidgetFrame >= 4) {
          _isFidgeting = false;
          timer.cancel();
        }
      });
    });
  }

  // ============================================
  // TCP Connection
  // ============================================

  Future<void> _connect() async {
    try {
      _socket = await Socket.connect(widget.host, widget.port);
      setState(() {
        _connected = true;
        _error = '';
      });

      _socket!.write('{"type":"subscribe"}\n');

      String buffer = '';
      _socket!.listen(
        (data) {
          buffer += utf8.decode(data);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            if (line.isEmpty) continue;
            _handleMessage(line);
          }
        },
        onDone: () {
          setState(() => _connected = false);
          Future.delayed(const Duration(seconds: 1), _connect);
        },
        onError: (e) {
          setState(() {
            _connected = false;
            _error = e.toString();
          });
          Future.delayed(const Duration(seconds: 1), _connect);
        },
      );
    } catch (e) {
      setState(() {
        _connected = false;
        _error = e.toString();
      });
      Future.delayed(const Duration(seconds: 1), _connect);
    }
  }

  void _handleMessage(String line) {
    try {
      final msg = json.decode(line) as Map<String, dynamic>;

      if (msg['type'] == 'frame') {
        final newEyesClosed = msg['blink'] == 'closed';

        // Trigger blink animation
        if (newEyesClosed != _wasEyesClosed) {
          if (newEyesClosed) {
            _blinkController.forward(from: 0);
          } else {
            _blinkController.reverse(from: 1);
          }
          _wasEyesClosed = newEyesClosed;
        }

        setState(() {
          _frame = msg['frame'] ?? 0;
          _currentViseme = msg['viseme'] ?? 'neutral_closed';
          _eyesClosed = newEyesClosed;
          _headRot = (msg['head']?['rot'] as num?)?.toDouble() ?? 0;
          _headY = (msg['head']?['y'] as num?)?.toDouble() ?? 0;
          _prevArmAngle = _armAngle; // Track previous for motion blur
          _armAngle = (msg['arm']?['right'] as num?)?.toDouble() ?? 0;
          _emotion = msg['emotion'] ?? 'chill';
        });
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
  }

  // ============================================
  // Gaze Follow (cursor tracking)
  // ============================================

  void _updateGaze(Offset cursorPos, Size screenSize) {
    // Calculate cursor position relative to center
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // Normalize to -1 to +1
    final normX = (cursorPos.dx - centerX) / centerX;
    final normY = (cursorPos.dy - centerY) / centerY;

    // Map to -3 to +3 degrees (subtle gaze)
    setState(() {
      _gazeX = normX.clamp(-1.0, 1.0) * 3.0;
      _gazeY = normY.clamp(-1.0, 1.0) * 2.0; // Less vertical
    });
  }

  // ============================================
  // Commands
  // ============================================

  void sendCommand(Map<String, dynamic> cmd) {
    if (_socket != null && _connected) {
      _socket!.write('${json.encode(cmd)}\n');
    }
  }

  void setViseme(String viseme) => sendCommand({'type': 'set_viseme', 'viseme': viseme});
  void setEmotion(String emotion) => sendCommand({'type': 'set_emotion', 'emotion': emotion});
  void triggerBlink() => sendCommand({'type': 'trigger_blink'});
  void speak(List<String> phonemes, {int fps = 12}) =>
      sendCommand({'type': 'speak', 'phonemes': phonemes, 'fps': fps});

  // ============================================
  // Build
  // ============================================

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _error.isEmpty ? 'Connecting to Terry...' : 'Error: $_error',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final mouthFile = _visemeToFile[_currentViseme] ?? 'x';

    return MouseRegion(
      onHover: (event) => _updateGaze(event.position, MediaQuery.of(context).size),
      child: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Frame: $_frame', style: _statusStyle),
                Text('Mouth: $_currentViseme', style: _statusStyle),
                Text('Mood: $_emotion', style: _statusStyle),
                if (_isFidgeting)
                  Text('Fidget: $_fidgetType', style: _statusStyle.copyWith(color: Colors.amber)),
              ],
            ),
          ),

          // Terry character
          Expanded(
            child: Center(
              child: SizedBox(
                width: 320,
                height: 420,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(0.0, _headY)
                    ..rotateZ((_headRot + _gazeX * 0.3) * pi / 180), // Gaze adds to rotation
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Body with breathing animation
                      Positioned(
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _breathAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _breathAnimation.value,
                              alignment: Alignment.bottomCenter,
                              child: child,
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                '${widget.assetPath}/layers/layer_10.png',
                                width: 220,
                                height: 260,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _placeholder(220, 260, 'Body'),
                              ),
                              // Chain sparkle overlay on medallion
                              Positioned(
                                top: 40,
                                child: AnimatedBuilder(
                                  animation: _sparkleAnimation,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _sparkleAnimation.value,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.amber.withOpacity(0.8),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Chain fidget overlay (behind arm)
                      if (_isFidgeting && _fidgetType == 'chain')
                        Positioned(
                          bottom: 120,
                          child: Image.asset(
                            '${widget.assetPath}/fidgets/chain_$_fidgetFrame.png',
                            width: 80,
                            height: 60,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => _fidgetPlaceholder('chain'),
                          ),
                        ),

                      // Right arm with motion blur
                      Positioned(
                        right: 15,
                        bottom: 90,
                        child: _buildArmWithMotionBlur(),
                      ),

                      // Head with gaze offset
                      Positioned(
                        top: 0,
                        child: Transform.translate(
                          offset: Offset(_gazeX * 0.5, _gazeY * 0.3), // Subtle gaze shift
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Head base
                              Image.asset(
                                '${widget.assetPath}/layers/layer_05.png',
                                width: 190,
                                height: 210,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _placeholder(190, 210, 'Head'),
                              ),

                              // Scratch fidget overlay (on dreads)
                              if (_isFidgeting && _fidgetType == 'scratch')
                                Positioned(
                                  top: 20,
                                  right: 30,
                                  child: Image.asset(
                                    '${widget.assetPath}/fidgets/scratch_$_fidgetFrame.png',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => _fidgetPlaceholder('scratch'),
                                  ),
                                ),

                              // Mouth — HARDCODED FOR DEBUG
                              Positioned(
                                bottom: 45,
                                child: Image.asset(
                                  'assets/characters/terry/mouth_shapes/x.png',
                                  width: 100,
                                  height: 70,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.red,
                                    width: 100,
                                    height: 70,
                                    child: const Center(child: Text('PATH DEAD', style: TextStyle(color: Colors.white, fontSize: 10))),
                                  ),
                                ),
                              ),

                              // Eyes with smooth blink
                              Positioned(
                                top: 65,
                                child: _buildEyes(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _btn('Blink', triggerBlink),
                _btn('Happy', () => setEmotion('happy')),
                _btn('Chill', () => setEmotion('chill')),
                _btn('Curious', () => setEmotion('curious')),
                _btn('Fidget', _doFidget),
                _btn('Say Hi', () => speak(['ah_open', 'ee_wide', 'neutral_closed'])),
                _btn('Oooh', () => speak(['oh', 'oo', 'oh', 'neutral_closed'], fps: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Arm with motion blur based on velocity
  Widget _buildArmWithMotionBlur() {
    // Calculate velocity (change per frame)
    final velocity = _armAngle - _prevArmAngle;
    final absVelocity = velocity.abs();

    // Motion blur offset (subtle, max 2px)
    final blurOffset = (velocity * 0.3).clamp(-2.0, 2.0);

    // Opacity for blur trail (more velocity = more visible trail)
    final trailOpacity = (absVelocity / 10).clamp(0.0, 0.3);

    return Transform.rotate(
      angle: _armAngle * pi / 180,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Stack(
          children: [
            // Motion blur trail (behind main arm)
            if (absVelocity > 0.5)
              Transform.translate(
                offset: Offset(blurOffset, 0),
                child: Opacity(
                  opacity: trailOpacity,
                  child: Image.asset(
                    '${widget.assetPath}/layers/layer_19.png',
                    width: 65,
                    height: 110,
                    fit: BoxFit.contain,
                    color: Colors.white.withOpacity(0.5),
                    colorBlendMode: BlendMode.modulate,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            // Main arm
            Image.asset(
              '${widget.assetPath}/layers/layer_19.png',
              width: 65,
              height: 110,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(65, 110, 'Arm'),
            ),
          ],
        ),
      ),
    );
  }

  /// Smooth animated eyes with 60ms fade
  Widget _buildEyes() {
    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 110,
          height: 35,
          child: Stack(
            children: [
              // Open eyes (fade out when closing)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 60),
                curve: Curves.easeOutCubic,
                opacity: _eyesClosed ? 0.0 : 1.0,
                child: _eyesOpenWidget(),
              ),
              // Closed eyes (fade in when closing)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 40), // Closes faster
                curve: Curves.easeOutCubic,
                opacity: _eyesClosed ? 1.0 : 0.0,
                child: _eyesClosedWidget(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eyesOpenWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildEyeball(_gazeX, _gazeY),
          _buildEyeball(_gazeX, _gazeY),
        ],
      ),
    );
  }

  Widget _eyesClosedWidget() {
    return Container(
      height: 8,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  /// Eyeball with pupil that follows gaze
  Widget _buildEyeball(double gazeX, double gazeY) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // Pupil with gaze offset
          Positioned(
            left: 9 + gazeX * 1.5, // Pupil follows gaze
            top: 9 + gazeY * 1.0,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Align(
                alignment: Alignment(-0.3, -0.3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 3, height: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _placeholder(double w, double h, String label) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        border: Border.all(color: Colors.grey.shade600),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    );
  }

  Widget _fidgetPlaceholder(String type) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$type $_fidgetFrame', style: const TextStyle(color: Colors.amber, fontSize: 9)),
    );
  }

  TextStyle get _statusStyle => const TextStyle(color: Colors.white70, fontSize: 11);
}

/// Standalone app
class TerryLiveApp extends StatelessWidget {
  const TerryLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terry Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const Scaffold(
        backgroundColor: Colors.black,
        body: TerryLiveViewer(),
      ),
    );
  }
}
