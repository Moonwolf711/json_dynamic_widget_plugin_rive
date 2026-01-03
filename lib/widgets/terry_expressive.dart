// terry_expressive.dart
// WFL Proprietary Character Renderer v1.0
// Copyright (c) 2024 Wooking For Love Project - All Rights Reserved
//
// Full expressive character with:
// - 27-point expression rig
// - Procedural eyebrow deformation
// - Pupil tracking and dilation
// - Micro-expression layering
// - Multi-layer compositing

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/expression_engine.dart';
import '../providers/terry_live_provider.dart';

/// Full expressive Terry with 27-point rig
class TerryExpressive extends StatefulWidget {
  final String character;
  final double scale;
  final bool showDebug;
  final bool useWebSocket;  // false = local animation only

  const TerryExpressive({
    super.key,
    this.character = 'terry',
    this.scale = 1.0,
    this.showDebug = false,
    this.useWebSocket = true,
  });

  @override
  State<TerryExpressive> createState() => TerryExpressiveState();
}

class TerryExpressiveState extends State<TerryExpressive>
    with SingleTickerProviderStateMixin {

  late final ExpressionController _expression;
  late final Ticker _ticker;
  Duration _lastTime = Duration.zero;

  ExpressionState _state = const ExpressionState(
    rig: {},
    blinkPhase: 0,
    gazeX: 0,
    gazeY: 0,
    currentEmotion: 'neutral',
  );

  int _visemeIdx = 0;

  @override
  void initState() {
    super.initState();
    _expression = ExpressionController();
    _expression.setExpression('chill', instant: true);

    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (_lastTime == Duration.zero)
        ? 0.016
        : (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    _expression.update(dt);
    setState(() {
      _state = _expression.exportState();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Public API
  void setExpression(String name) => _expression.setExpression(name);
  void setViseme(int idx) => setState(() => _visemeIdx = idx);
  void blink() => _expression.blink();
  void doubleBlink() => _expression.doubleBlink();
  void lookAt(double x, double y) => _expression.lookAt(x, y);
  void lookAtCamera() => _expression.lookAtCamera();

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: widget.scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer stack from back to front
          _buildBody(),
          _buildArms(),
          _buildHead(),
          if (widget.showDebug) _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Image.asset(
      'assets/${widget.character}/body.png',
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox(width: 200, height: 300),
    );
  }

  Widget _buildArms() {
    // Arm sway from expression rig
    final armSwayL = (_state.rig['head_roll'] ?? 0) * -20;
    final armSwayR = (_state.rig['head_roll'] ?? 0) * 15;

    return Stack(
      children: [
        // Left arm
        Positioned(
          left: 30,
          top: 180,
          child: Transform.rotate(
            angle: armSwayL * math.pi / 180,
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/${widget.character}/arm_left.png',
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        // Right arm
        Positioned(
          right: 30,
          top: 180,
          child: Transform.rotate(
            angle: armSwayR * math.pi / 180,
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/${widget.character}/arm_right.png',
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHead() {
    return Transform.translate(
      offset: Offset(0, _state.headPitchDegrees * 0.5),
      child: Transform.rotate(
        angle: _state.headRollDegrees * math.pi / 180,
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)  // perspective
            ..rotateY(_state.headYawDegrees * math.pi / 180),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Base head/face
              _buildFaceBase(),
              // Eyebrows
              _buildEyebrows(),
              // Eyes with lids
              _buildEyes(),
              // Nose
              _buildNose(),
              // Mouth
              _buildMouth(),
              // Cheeks (for expressions)
              _buildCheeks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaceBase() {
    return Image.asset(
      'assets/${widget.character}/head.png',
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        width: 150,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildEyebrows() {
    return Stack(
      children: [
        // Left eyebrow
        Positioned(
          left: 35,
          top: 45 - _state.browLeftY,
          child: Transform.rotate(
            angle: _state.browLeftRotation * 0.2,
            child: _EyebrowPainter(
              width: 40,
              height: 12,
              color: const Color(0xFF2D1810),
              bend: _state.rig['brow_l_mid'] ?? 0,
              innerRaise: _state.rig['brow_l_in'] ?? 0,
              outerRaise: _state.rig['brow_l_out'] ?? 0,
            ),
          ),
        ),
        // Right eyebrow
        Positioned(
          right: 35,
          top: 45 - _state.browRightY,
          child: Transform.rotate(
            angle: -_state.browRightRotation * 0.2,
            child: Transform.flip(
              flipX: true,
              child: _EyebrowPainter(
                width: 40,
                height: 12,
                color: const Color(0xFF2D1810),
                bend: _state.rig['brow_r_mid'] ?? 0,
                innerRaise: _state.rig['brow_r_in'] ?? 0,
                outerRaise: _state.rig['brow_r_out'] ?? 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEyes() {
    final lidClosureL = _state.lidLeftClosure + _state.blinkPhase * 0.8;
    final lidClosureR = _state.lidRightClosure + _state.blinkPhase * 0.8;

    return Stack(
      children: [
        // Left eye
        Positioned(
          left: 40,
          top: 65,
          child: _EyeWidget(
            width: 35,
            height: 25,
            pupilX: _state.gazeX,
            pupilY: _state.gazeY,
            pupilDilation: _state.pupilDilation,
            lidClosure: lidClosureL.clamp(0.0, 1.0),
            irisColor: const Color(0xFF4A7C59),  // Terry's alien green
          ),
        ),
        // Right eye
        Positioned(
          right: 40,
          top: 65,
          child: _EyeWidget(
            width: 35,
            height: 25,
            pupilX: _state.gazeX,
            pupilY: _state.gazeY,
            pupilDilation: _state.pupilDilation,
            lidClosure: lidClosureR.clamp(0.0, 1.0),
            irisColor: const Color(0xFF4A7C59),
          ),
        ),
      ],
    );
  }

  Widget _buildNose() {
    final flareL = (_state.rig['nostril_l'] ?? 0) * 3;
    final flareR = (_state.rig['nostril_r'] ?? 0) * 3;

    return Positioned(
      top: 95,
      child: SizedBox(
        width: 30,
        height: 20,
        child: CustomPaint(
          painter: _NosePainter(
            leftFlare: flareL,
            rightFlare: flareR,
          ),
        ),
      ),
    );
  }

  Widget _buildMouth() {
    final cornerL = _state.mouthSmileLeft;
    final cornerR = _state.mouthSmileRight;
    final stretch = _state.rig['mouth_stretch'] ?? 0;

    return Positioned(
      bottom: 40,
      child: _MouthWidget(
        visemeIdx: _visemeIdx,
        character: widget.character,
        smileLeft: cornerL,
        smileRight: cornerR,
        stretch: stretch,
      ),
    );
  }

  Widget _buildCheeks() {
    final cheekL = (_state.rig['cheek_l'] ?? 0).clamp(0.0, 1.0);
    final cheekR = (_state.rig['cheek_r'] ?? 0).clamp(0.0, 1.0);

    if (cheekL < 0.1 && cheekR < 0.1) return const SizedBox.shrink();

    return Stack(
      children: [
        if (cheekL > 0.1)
          Positioned(
            left: 25,
            top: 90,
            child: Opacity(
              opacity: cheekL * 0.5,
              child: Container(
                width: 20,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A0A0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        if (cheekR > 0.1)
          Positioned(
            right: 25,
            top: 90,
            child: Opacity(
              opacity: cheekR * 0.5,
              child: Container(
                width: 20,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A0A0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      bottom: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Emotion: ${_state.currentEmotion}\n'
          'Blink: ${(_state.blinkPhase * 100).toInt()}%\n'
          'Gaze: (${_state.gazeX.toStringAsFixed(2)}, ${_state.gazeY.toStringAsFixed(2)})\n'
          'Head: Y${_state.headYawDegrees.toStringAsFixed(1)}° P${_state.headPitchDegrees.toStringAsFixed(1)}° R${_state.headRollDegrees.toStringAsFixed(1)}°\n'
          'Brows: L${_state.browLeftY.toStringAsFixed(1)} R${_state.browRightY.toStringAsFixed(1)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

// ============================================
// Custom Painters for procedural features
// ============================================

/// Procedural eyebrow with deformation
class _EyebrowPainter extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double bend;        // -1 to 1
  final double innerRaise;  // -1 to 1
  final double outerRaise;  // -1 to 1

  const _EyebrowPainter({
    required this.width,
    required this.height,
    required this.color,
    this.bend = 0,
    this.innerRaise = 0,
    this.outerRaise = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height + 10,  // Extra space for deformation
      child: CustomPaint(
        painter: _EyebrowCustomPainter(
          color: color,
          bend: bend,
          innerRaise: innerRaise,
          outerRaise: outerRaise,
        ),
      ),
    );
  }
}

class _EyebrowCustomPainter extends CustomPainter {
  final Color color;
  final double bend;
  final double innerRaise;
  final double outerRaise;

  _EyebrowCustomPainter({
    required this.color,
    required this.bend,
    required this.innerRaise,
    required this.outerRaise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Control points for bezier curve
    final innerY = size.height * 0.5 - innerRaise * 8;
    final midY = size.height * 0.3 - bend * 6;
    final outerY = size.height * 0.5 - outerRaise * 8;

    // Top edge
    path.moveTo(0, innerY);
    path.quadraticBezierTo(
      size.width * 0.5, midY - 4,
      size.width, outerY,
    );

    // Bottom edge (thinner)
    path.lineTo(size.width, outerY + 4);
    path.quadraticBezierTo(
      size.width * 0.5, midY + 2,
      0, innerY + 5,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EyebrowCustomPainter old) =>
      old.bend != bend || old.innerRaise != innerRaise || old.outerRaise != outerRaise;
}

/// Procedural eye with pupil, iris, and lids
class _EyeWidget extends StatelessWidget {
  final double width;
  final double height;
  final double pupilX;       // -1 to 1
  final double pupilY;       // -1 to 1
  final double pupilDilation;  // 0.7 to 1.3
  final double lidClosure;   // 0 to 1
  final Color irisColor;

  const _EyeWidget({
    required this.width,
    required this.height,
    this.pupilX = 0,
    this.pupilY = 0,
    this.pupilDilation = 1.0,
    this.lidClosure = 0,
    required this.irisColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _EyeCustomPainter(
          pupilX: pupilX,
          pupilY: pupilY,
          pupilDilation: pupilDilation,
          lidClosure: lidClosure,
          irisColor: irisColor,
        ),
      ),
    );
  }
}

class _EyeCustomPainter extends CustomPainter {
  final double pupilX;
  final double pupilY;
  final double pupilDilation;
  final double lidClosure;
  final Color irisColor;

  _EyeCustomPainter({
    required this.pupilX,
    required this.pupilY,
    required this.pupilDilation,
    required this.lidClosure,
    required this.irisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Sclera (white of eye)
    final scleraPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      scleraPaint,
    );

    // Iris
    final irisRadius = size.height * 0.4;
    final irisOffset = Offset(
      center.dx + pupilX * size.width * 0.15,
      center.dy + pupilY * size.height * 0.1,
    );

    final irisPaint = Paint()
      ..color = irisColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(irisOffset, irisRadius, irisPaint);

    // Pupil
    final pupilRadius = irisRadius * 0.5 * pupilDilation;
    final pupilPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(irisOffset, pupilRadius, pupilPaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      irisOffset + Offset(-irisRadius * 0.3, -irisRadius * 0.3),
      irisRadius * 0.2,
      highlightPaint,
    );

    // Eyelid (closes from top)
    if (lidClosure > 0) {
      final lidPaint = Paint()
        ..color = const Color(0xFF8B7355)  // Skin tone
        ..style = PaintingStyle.fill;

      final lidHeight = size.height * lidClosure;
      final lidPath = Path();
      lidPath.moveTo(0, 0);
      lidPath.lineTo(size.width, 0);
      lidPath.lineTo(size.width, lidHeight);
      lidPath.quadraticBezierTo(
        size.width / 2, lidHeight + 5,
        0, lidHeight,
      );
      lidPath.close();

      canvas.drawPath(lidPath, lidPaint);
    }

    // Eye outline
    final outlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      outlinePaint,
    );
  }

  @override
  bool shouldRepaint(_EyeCustomPainter old) =>
      old.pupilX != pupilX ||
      old.pupilY != pupilY ||
      old.lidClosure != lidClosure ||
      old.pupilDilation != pupilDilation;
}

/// Nose with nostril flare
class _NosePainter extends CustomPainter {
  final double leftFlare;
  final double rightFlare;

  _NosePainter({this.leftFlare = 0, this.rightFlare = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B5344)
      ..style = PaintingStyle.fill;

    // Left nostril
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.3 - leftFlare, size.height * 0.6),
        width: 6 + leftFlare,
        height: 4,
      ),
      paint,
    );

    // Right nostril
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.7 + rightFlare, size.height * 0.6),
        width: 6 + rightFlare,
        height: 4,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_NosePainter old) =>
      old.leftFlare != leftFlare || old.rightFlare != rightFlare;
}

/// Mouth with viseme + expression overlay
class _MouthWidget extends StatelessWidget {
  final int visemeIdx;
  final String character;
  final double smileLeft;
  final double smileRight;
  final double stretch;

  const _MouthWidget({
    required this.visemeIdx,
    required this.character,
    this.smileLeft = 0,
    this.smileRight = 0,
    this.stretch = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Average smile for scaling
    final smile = (smileLeft + smileRight) / 2;

    return Transform(
      transform: Matrix4.identity()
        ..scale(1.0 + stretch * 0.2, 1.0 - stretch * 0.1)
        ..rotateZ((smileRight - smileLeft) * 0.05),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base mouth from viseme
          Image.asset(
            'assets/$character/mouths/${visemeNames[visemeIdx]}.png',
            width: 80 + smile * 10,
            height: 50,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _FallbackMouth(
              smile: smile,
              stretch: stretch,
            ),
          ),
          // Smile corner overlays
          if (smile > 0.2)
            Opacity(
              opacity: (smile - 0.2) * 1.25,
              child: Image.asset(
                'assets/$character/mouth_smile_overlay.png',
                width: 80,
                height: 50,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fallback procedural mouth
class _FallbackMouth extends StatelessWidget {
  final double smile;
  final double stretch;

  const _FallbackMouth({this.smile = 0, this.stretch = 0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 50,
      child: CustomPaint(
        painter: _FallbackMouthPainter(smile: smile, stretch: stretch),
      ),
    );
  }
}

class _FallbackMouthPainter extends CustomPainter {
  final double smile;
  final double stretch;

  _FallbackMouthPainter({this.smile = 0, this.stretch = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B3A3A)
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Mouth shape affected by smile
    final cornerDrop = smile * 8;
    final width = size.width * (0.6 + stretch * 0.2);

    path.moveTo(cx - width / 2, cy);
    path.quadraticBezierTo(
      cx, cy + 10 - cornerDrop,
      cx + width / 2, cy,
    );
    path.quadraticBezierTo(
      cx, cy - 5 + cornerDrop,
      cx - width / 2, cy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FallbackMouthPainter old) =>
      old.smile != smile || old.stretch != stretch;
}

// ============================================
// WebSocket-connected version
// ============================================

/// TerryExpressive with WebSocket state sync
class TerryExpressiveConnected extends ConsumerStatefulWidget {
  final String character;
  final double scale;
  final bool showDebug;

  const TerryExpressiveConnected({
    super.key,
    this.character = 'terry',
    this.scale = 1.0,
    this.showDebug = false,
  });

  @override
  ConsumerState<TerryExpressiveConnected> createState() =>
      _TerryExpressiveConnectedState();
}

class _TerryExpressiveConnectedState
    extends ConsumerState<TerryExpressiveConnected> {

  final GlobalKey<TerryExpressiveState> _terryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Watch animation state from WebSocket
    final asyncState = ref.watch(animationProvider);

    return asyncState.when(
      data: (state) {
        // Sync emotion to expression engine
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _terryKey.currentState?.setExpression(state.emotion);
          _terryKey.currentState?.setViseme(state.visemeIdx);
        });

        return TerryExpressive(
          key: _terryKey,
          character: widget.character,
          scale: widget.scale,
          showDebug: widget.showDebug,
          useWebSocket: true,
        );
      },
      loading: () => TerryExpressive(
        character: widget.character,
        scale: widget.scale,
        showDebug: widget.showDebug,
        useWebSocket: false,
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('Offline mode', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
