/// WFL Skeleton Animation System
/// Hierarchical bone model + State machine + Procedural animation
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

// ==================== 1. BONE DATA MODEL ====================

/// A single bone in the skeleton hierarchy
class Bone {
  final String name;
  final Bone? parent;
  double length;
  double rotation; // radians (local rotation relative to parent)
  Offset localOffset; // offset from parent's end

  // Sprite attachment
  String? spritePath;
  Offset spriteOffset;
  double spriteScale;

  Bone({
    required this.name,
    required this.length,
    this.parent,
    this.rotation = 0,
    this.localOffset = Offset.zero,
    this.spritePath,
    this.spriteOffset = Offset.zero,
    this.spriteScale = 1.0,
  });

  /// World rotation (accumulated from all parents)
  double get worldRotation {
    if (parent == null) return rotation;
    return parent!.worldRotation + rotation;
  }

  /// Start position (end of parent, or origin if root)
  Offset get start {
    if (parent == null) return localOffset;
    return parent!.end + localOffset;
  }

  /// End position (start + length at world rotation angle)
  Offset get end {
    return start +
        Offset(
          cos(worldRotation) * length,
          sin(worldRotation) * length,
        );
  }

  /// Center point of the bone
  Offset get center => Offset.lerp(start, end, 0.5)!;
}

// ==================== 2. SKELETON (COLLECTION OF BONES) ====================

/// A complete skeleton with named bones
class WFLSkeleton {
  final String name;
  final Map<String, Bone> bones = {};
  final List<Bone> renderOrder = []; // Bottom to top

  WFLSkeleton({required this.name});

  /// Add a bone to the skeleton
  void addBone(Bone bone) {
    bones[bone.name] = bone;
    renderOrder.add(bone);
  }

  /// Get bone by name
  Bone? getBone(String name) => bones[name];

  /// Reset all rotations to zero
  void resetPose() {
    for (final bone in bones.values) {
      bone.rotation = 0;
    }
  }
}

// ==================== 3. CHARACTER STATES ====================

/// Animation states for characters
enum CharacterState {
  idle, // Subtle breathing, eye wander
  talking, // Mouth moving, head bob
  listening, // Attentive, slight nod
  laughing, // Big motion, shake
  surprised, // Eyebrows up, lean back
  angry, // Lean forward, frown
  thinking, // Eye up/left, head tilt
  waving, // Arm wave
  nodding, // Head nod
  shaking, // Head shake
}

// ==================== 4. POSE DATA ====================

/// A pose is a snapshot of all bone rotations
class Pose {
  final Map<String, double> rotations;
  final Map<String, Offset> offsets;

  const Pose({
    this.rotations = const {},
    this.offsets = const {},
  });

  /// Blend between two poses
  static Pose lerp(Pose a, Pose b, double t) {
    final rotations = <String, double>{};
    final offsets = <String, Offset>{};

    // Blend rotations
    for (final key in {...a.rotations.keys, ...b.rotations.keys}) {
      final aVal = a.rotations[key] ?? 0;
      final bVal = b.rotations[key] ?? 0;
      rotations[key] = lerpDouble(aVal, bVal, t)!;
    }

    // Blend offsets
    for (final key in {...a.offsets.keys, ...b.offsets.keys}) {
      final aVal = a.offsets[key] ?? Offset.zero;
      final bVal = b.offsets[key] ?? Offset.zero;
      offsets[key] = Offset.lerp(aVal, bVal, t)!;
    }

    return Pose(rotations: rotations, offsets: offsets);
  }

  /// Apply this pose to a skeleton
  void apply(WFLSkeleton skeleton) {
    for (final entry in rotations.entries) {
      skeleton.getBone(entry.key)?.rotation = entry.value;
    }
    for (final entry in offsets.entries) {
      skeleton.getBone(entry.key)?.localOffset = entry.value;
    }
  }
}

// ==================== 5. STATE MACHINE ====================

/// Controls character animation states and transitions
class SkeletonStateMachine {
  CharacterState _currentState = CharacterState.idle;
  CharacterState _previousState = CharacterState.idle;
  double _transitionProgress = 1.0; // 0 = previous, 1 = current
  final double transitionSpeed;

  // Pose library for this character
  final Map<CharacterState, Pose> poses;

  // Procedural animation parameters
  double _time = 0;

  SkeletonStateMachine({
    this.poses = const {},
    this.transitionSpeed = 3.0,
  });

  CharacterState get currentState => _currentState;
  bool get isTransitioning => _transitionProgress < 1.0;

  /// Change to a new state
  void setState(CharacterState newState) {
    if (newState == _currentState) return;
    _previousState = _currentState;
    _currentState = newState;
    _transitionProgress = 0.0;
  }

  /// Update animation (call every frame)
  void update(WFLSkeleton skeleton, double dt) {
    _time += dt;

    // Progress transition
    if (_transitionProgress < 1.0) {
      _transitionProgress =
          (_transitionProgress + dt * transitionSpeed).clamp(0.0, 1.0);
    }

    // Calculate procedural motion based on state
    final proceduralPose = _calculateProceduralPose(_currentState, _time);

    // Blend with base poses if defined
    final basePose = poses[_currentState] ?? const Pose();
    final previousBasePose = poses[_previousState] ?? const Pose();

    // Blend between previous and current state
    final blendedBase =
        Pose.lerp(previousBasePose, basePose, _transitionProgress);

    // Apply blended base + procedural
    blendedBase.apply(skeleton);
    proceduralPose.apply(skeleton);
  }

  /// Generate procedural motion for each state
  Pose _calculateProceduralPose(CharacterState state, double t) {
    final rotations = <String, double>{};
    final offsets = <String, Offset>{};

    switch (state) {
      case CharacterState.idle:
        // Subtle breathing
        rotations['body'] = sin(t * 0.8) * 0.02;
        offsets['body'] = Offset(0, sin(t * 1.2) * 2);
        // Eye wander
        offsets['eyes'] = Offset(sin(t * 0.5) * 3, cos(t * 0.7) * 2);
        break;

      case CharacterState.talking:
        // Head bob while talking
        rotations['head'] = sin(t * 4) * 0.05;
        offsets['body'] = Offset(sin(t * 2) * 2, sin(t * 3) * 3);
        // Mouth handled separately by lip-sync
        break;

      case CharacterState.listening:
        // Slight forward lean, occasional nod
        rotations['body'] = 0.05 + sin(t * 0.5) * 0.02;
        rotations['head'] = sin(t * 1.5) * 0.03;
        break;

      case CharacterState.laughing:
        // Big shaking motion
        rotations['body'] = sin(t * 8) * 0.1;
        offsets['body'] = Offset(sin(t * 10) * 3, sin(t * 12) * 5);
        rotations['head'] = sin(t * 6) * 0.15;
        break;

      case CharacterState.surprised:
        // Lean back, eyes wide
        rotations['body'] = -0.1;
        offsets['eyes'] = Offset(0, -5); // Eyes up
        break;

      case CharacterState.angry:
        // Lean forward, subtle shake
        rotations['body'] = 0.1 + sin(t * 15) * 0.02;
        rotations['head'] = sin(t * 20) * 0.03;
        break;

      case CharacterState.thinking:
        // Head tilt, eyes up/left
        rotations['head'] = 0.1;
        offsets['eyes'] = Offset(-5, -3);
        break;

      case CharacterState.waving:
        // Arm swing
        rotations['arm'] = sin(t * 6) * 0.8;
        break;

      case CharacterState.nodding:
        // Vertical head motion
        rotations['head'] = sin(t * 3) * 0.15;
        break;

      case CharacterState.shaking:
        // Horizontal head motion
        offsets['head'] = Offset(sin(t * 8) * 10, 0);
        break;
    }

    return Pose(rotations: rotations, offsets: offsets);
  }
}

// ==================== 6. SKELETON PAINTER ====================

/// CustomPainter for rendering skeleton (debug view)
class SkeletonPainter extends CustomPainter {
  final WFLSkeleton skeleton;
  final bool showBones;
  final bool showJoints;
  final Map<String, ImageProvider>? sprites;

  SkeletonPainter({
    required this.skeleton,
    this.showBones = true,
    this.showJoints = true,
    this.sprites,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    final bonePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    for (final bone in skeleton.renderOrder) {
      if (showBones) {
        canvas.drawLine(bone.start, bone.end, bonePaint);
      }
      if (showJoints) {
        canvas.drawCircle(bone.start, 6, jointPaint);
        canvas.drawCircle(bone.end, 4, jointPaint..color = Colors.orange);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==================== 7. ANIMATED SKELETON WIDGET ====================

/// Widget that renders and animates a skeleton with state machine
class AnimatedSkeleton extends StatefulWidget {
  final WFLSkeleton skeleton;
  final CharacterState initialState;
  final Map<CharacterState, Pose>? poses;
  final bool showDebugBones;
  final Widget Function(BuildContext, WFLSkeleton)? spriteBuilder;

  const AnimatedSkeleton({
    super.key,
    required this.skeleton,
    this.initialState = CharacterState.idle,
    this.poses,
    this.showDebugBones = false,
    this.spriteBuilder,
  });

  @override
  State<AnimatedSkeleton> createState() => AnimatedSkeletonState();
}

class AnimatedSkeletonState extends State<AnimatedSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late SkeletonStateMachine _stateMachine;
  double _lastTime = 0;

  SkeletonStateMachine get stateMachine => _stateMachine;

  @override
  void initState() {
    super.initState();

    _stateMachine = SkeletonStateMachine(
      poses: widget.poses ?? {},
    );
    _stateMachine.setState(widget.initialState);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);

    _controller.repeat();
  }

  void _onTick() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final dt = now - _lastTime;
    _lastTime = now;

    if (dt > 0 && dt < 0.1) {
      // Clamp to avoid huge jumps
      setState(() {
        _stateMachine.update(widget.skeleton, dt);
      });
    }
  }

  /// Change character state
  void setCharacterState(CharacterState state) {
    _stateMachine.setState(state);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sprite layer (if builder provided)
        if (widget.spriteBuilder != null)
          widget.spriteBuilder!(context, widget.skeleton),

        // Debug bone overlay
        if (widget.showDebugBones)
          CustomPaint(
            size: const Size(400, 400),
            painter: SkeletonPainter(
              skeleton: widget.skeleton,
              showBones: true,
              showJoints: true,
            ),
          ),
      ],
    );
  }
}

// ==================== 8. FACTORY FOR WFL CHARACTERS ====================

/// Factory to create Terry and Nigel skeletons
class WFLSkeletonFactory {
  /// Create Terry's skeleton
  static WFLSkeleton createTerry() {
    final skeleton = WFLSkeleton(name: 'terry');

    // Root bone (body center)
    final body = Bone(name: 'body', length: 0);
    skeleton.addBone(body);

    // Head attached to body
    final head = Bone(
      name: 'head',
      length: 40,
      parent: body,
      rotation: -pi / 2, // Points up
    );
    skeleton.addBone(head);

    // Eyes (offset from head, no length - just position marker)
    final eyes = Bone(
      name: 'eyes',
      length: 0,
      parent: head,
      localOffset: const Offset(0, -30),
    );
    skeleton.addBone(eyes);

    // Mouth (offset from head)
    final mouth = Bone(
      name: 'mouth',
      length: 0,
      parent: head,
      localOffset: const Offset(0, -50),
    );
    skeleton.addBone(mouth);

    return skeleton;
  }

  /// Create Nigel's skeleton
  static WFLSkeleton createNigel() {
    final skeleton = WFLSkeleton(name: 'nigel');

    // Similar structure to Terry with different proportions
    final body = Bone(name: 'body', length: 0);
    skeleton.addBone(body);

    final head = Bone(
      name: 'head',
      length: 45,
      parent: body,
      rotation: -pi / 2,
    );
    skeleton.addBone(head);

    final eyes = Bone(
      name: 'eyes',
      length: 0,
      parent: head,
      localOffset: const Offset(0, -35),
    );
    skeleton.addBone(eyes);

    final mouth = Bone(
      name: 'mouth',
      length: 0,
      parent: head,
      localOffset: const Offset(0, -55),
    );
    skeleton.addBone(mouth);

    return skeleton;
  }
}