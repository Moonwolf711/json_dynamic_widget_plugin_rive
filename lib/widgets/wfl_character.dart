import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

import '../bone_animation.dart';
import '../rive_stub.dart';
import '../wfl_animations.dart';
import '../wfl_models.dart';
import 'wfl_resizable_component.dart';

class WFLCharacter extends StatelessWidget {
  final String name;
  final bool riveLoaded;
  final Artboard? riveArtboard;
  final bool skeletonsLoaded;
  final Skeleton? skeleton;
  final String? boneAnimation;
  final GlobalKey<BoneAnimatorWidgetState>? boneKey;
  final String mouthShape;
  final String blinkState;

  // Reaction modifiers
  final double bobMultiplier;
  final double swayMultiplier;
  final double leanOffset;

  // Transform state
  final double bodyScale;
  final Offset bodyOffset;
  final double eyesScale;
  final Offset eyesOffset;
  final double mouthScale;
  final Offset mouthOffset;

  // Callbacks
  final Function(double) onBodyScaleUpdate;
  final Function(Offset) onBodyDragUpdate;
  final VoidCallback onBodyReset;
  final Function(double) onEyesScaleUpdate;
  final Function(Offset) onEyesDragUpdate;
  final VoidCallback onEyesReset;
  final Function(double) onMouthScaleUpdate;
  final Function(Offset) onMouthDragUpdate;
  final VoidCallback onMouthReset;

  // Constants (could be passed or kept here)
  static const double minScale = 0.3;
  static const double maxScale = 3.0;
  static const double defaultScale = 1.0;

  const WFLCharacter({
    super.key,
    required this.name,
    required this.riveLoaded,
    this.riveArtboard,
    required this.skeletonsLoaded,
    this.skeleton,
    this.boneAnimation,
    this.boneKey,
    required this.mouthShape,
    required this.blinkState,
    this.bobMultiplier = 1.0,
    this.swayMultiplier = 1.0,
    this.leanOffset = 0.0,
    required this.bodyScale,
    required this.bodyOffset,
    required this.eyesScale,
    required this.eyesOffset,
    required this.mouthScale,
    required this.mouthOffset,
    required this.onBodyScaleUpdate,
    required this.onBodyDragUpdate,
    required this.onBodyReset,
    required this.onEyesScaleUpdate,
    required this.onEyesDragUpdate,
    required this.onEyesReset,
    required this.onMouthScaleUpdate,
    required this.onMouthDragUpdate,
    required this.onMouthReset,
  });

  @override
  Widget build(BuildContext context) {
    // Priority 1: Rive bone animation
    if (riveLoaded && riveArtboard != null) {
      debugPrint('WFLCharacter($name): Using RIVE');
      return _buildRiveCharacter();
    }

    // Priority 2: Custom bone animation system
    if (skeletonsLoaded && skeleton != null) {
      debugPrint('WFLCharacter($name): Using BONE ANIMATION');
      return _buildBoneCharacter();
    }

    // Priority 3: PNG fallback
    debugPrint(
        'WFLCharacter($name): Using PNG FALLBACK (skeletonsLoaded=$skeletonsLoaded, skeleton=${skeleton != null})');
    return _buildPngCharacter();
  }

  Widget _buildRiveCharacter() {
    return SizedBox(
      width: 300,
      height: 400,
      child: Rive(
        artboard: riveArtboard!,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }

  Widget _buildBoneCharacter() {
    final basePath = 'assets/characters/$name';
    final bodyColor = name == 'terry' ? Colors.cyan : Colors.lightGreen;

    return Transform.translate(
      offset: bodyOffset,
      child: WFLResizableComponent(
        label: '${name.toUpperCase()} CHARACTER',
        color: bodyColor,
        scale: bodyScale,
        onScaleUpdate: onBodyScaleUpdate,
        onDragUpdate: onBodyDragUpdate,
        onReset: onBodyReset,
        child: SizedBox(
          width: skeleton!.canvasSize.width * 0.6,
          height: skeleton!.canvasSize.height * 0.6,
          child: BoneAnimatorWidget(
            key: boneKey,
            skeleton: skeleton!,
            currentAnimation: boneAnimation,
            assetBasePath: basePath,
            scale: 0.6,
            showBones: false,
          ),
        ),
      ),
    );
  }

  Widget _buildPngCharacter() {
    final config = WFLCharacterConfig.characters[name] ??
        WFLCharacterConfig.characters['terry']!;

    // Select the appropriate layer-specific tweens for this character
    final bodyTween = name == 'terry' ? terryBodyTween : nigelBodyTween;
    final eyesTween = name == 'terry' ? terryEyesTween : nigelEyesTween;
    final mouthTween = name == 'terry' ? terryMouthTween : nigelMouthTween;

    final bodyColor = name == 'terry' ? Colors.cyan : Colors.lightGreen;
    final eyesColor = name == 'terry' ? Colors.blue : Colors.teal;
    final mouthColor = name == 'terry' ? Colors.orange : Colors.amber;

    final bodyImage = Image.asset(
      'assets/characters/$name/body.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    return SizedBox(
      width: 450,
      height: 500,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // ==================== BODY LAYER ====================
          // Has its own state machine for breathing, sway, lean
          MirrorAnimationBuilder<Movie>(
            tween: bodyTween,
            duration: bodyTween.duration,
            builder: (context, bodyValue, child) {
              final breathY = bodyValue.get<double>('breathY');
              final sway = bodyValue.get<double>('sway');
              final lean = bodyValue.get<double>('lean');

              return Positioned(
                left: bodyOffset.dx + (sway * swayMultiplier),
                bottom: bodyOffset.dy + breathY,
                child: Transform(
                  transform: Matrix4.identity()
                    ..rotateZ((lean * 0.01) + leanOffset),
                  alignment: Alignment.bottomCenter,
                  child: WFLResizableComponent(
                    label: '${name.toUpperCase()} BODY',
                    color: bodyColor,
                    scale: bodyScale,
                    onScaleUpdate: onBodyScaleUpdate,
                    onDragUpdate: onBodyDragUpdate,
                    onReset: onBodyReset,
                    child: SizedBox(
                      width: config['bodyAspectRatio'] != null ? 400 : 300,
                      height: config['bodyAspectRatio'] != null
                          ? (400 / (config['bodyAspectRatio'] as double))
                              .round()
                              .toDouble()
                          : 400,
                      child: bodyImage,
                    ),
                  ),
                ),
              );
            },
          ),

          // ==================== EYES LAYER ====================
          // Has its own state machine for wandering, focus
          if (config['hasEyes'] == true)
            MirrorAnimationBuilder<Movie>(
              tween: eyesTween,
              duration: eyesTween.duration,
              builder: (context, eyesValue, child) {
                final eyeX = eyesValue.get<double>('eyeX');
                final eyeY = eyesValue.get<double>('eyeY');
                final focus = eyesValue.get<double>('focus');

                final containerHeight = config['bodyAspectRatio'] != null
                    ? (400 / (config['bodyAspectRatio'] as double))
                        .round()
                        .toDouble()
                    : 400.0;

                return Positioned(
                  left: bodyOffset.dx +
                      (config['eyesX'] as double) +
                      eyeX +
                      eyesOffset.dx,
                  bottom: bodyOffset.dy +
                      (containerHeight -
                          (config['eyesY'] as double) -
                          eyeY -
                          focus) +
                      eyesOffset.dy,
                  child: WFLResizableComponent(
                    label: '${name.toUpperCase()} EYES',
                    color: eyesColor,
                    scale: eyesScale,
                    onScaleUpdate: onEyesScaleUpdate,
                    onDragUpdate: onEyesDragUpdate,
                    onReset: onEyesReset,
                    child: Image.asset(
                      'assets/characters/$name/eyes/eyes_$blinkState.png',
                      width: config['eyesWidth'] as double,
                      height: config['eyesHeight'] as double,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 40,
                        color: eyesColor.withAlpha(77),
                        child: const Center(
                            child: Text('EYES',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10))),
                      ),
                    ),
                  ),
                );
              },
            ),

          // ==================== MOUTH LAYER ====================
          // Has its own state machine for expression shifts
          if (config['mouthFullFrame'] == true)
            // Full-frame mouth (Nigel) - just follows body, no separate animation
            Positioned(
              left: bodyOffset.dx,
              bottom: bodyOffset.dy,
              child: IgnorePointer(
                child: SizedBox(
                  width: config['bodyAspectRatio'] != null ? 400 : 300,
                  height: config['bodyAspectRatio'] != null
                      ? (400 / (config['bodyAspectRatio'] as double))
                          .round()
                          .toDouble()
                      : 400,
                  child: Image.asset(
                    'assets/characters/$name/mouth_shapes/$mouthShape.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            )
          else
            // Separate mouth layer (Terry) - has own animation
            MirrorAnimationBuilder<Movie>(
              tween: mouthTween,
              duration: mouthTween.duration,
              builder: (context, mouthValue, child) {
                final mouthX = mouthValue.get<double>('mouthX');
                final mouthY = mouthValue.get<double>('mouthY');

                return Positioned(
                  left: bodyOffset.dx +
                      (config['mouthX'] as double) +
                      mouthX +
                      mouthOffset.dx,
                  bottom: bodyOffset.dy +
                      (400 - (config['mouthY'] as double)) +
                      mouthY +
                      mouthOffset.dy,
                  child: WFLResizableComponent(
                    label: '${name.toUpperCase()} MOUTH',
                    color: mouthColor,
                    scale: mouthScale,
                    onScaleUpdate: onMouthScaleUpdate,
                    onDragUpdate: onMouthDragUpdate,
                    onReset: onMouthReset,
                    child: Image.asset(
                      'assets/characters/$name/mouth_shapes/$mouthShape.png',
                      width: config['mouthWidth'] as double,
                      height: config['mouthHeight'] as double,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 40,
                        color: mouthColor.withAlpha(77),
                        child: const Center(
                            child: Text('MOUTH',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10))),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
