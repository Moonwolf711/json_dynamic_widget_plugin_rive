/// WFL Bone Animation System
/// Custom skeletal animation for PNG layers without external tools
library bone_animation;

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents a single bone in the skeleton
class Bone {
  final String name;
  final String? parentName;
  final Offset pivot;       // Rotation pivot point (0-1 normalized)
  final Offset position;    // Position relative to parent
  final double rotation;    // Current rotation in radians
  final double length;      // Bone length for visualization
  final List<String> attachedImages; // PNG layers attached to this bone

  Bone({
    required this.name,
    this.parentName,
    this.pivot = const Offset(0.5, 1.0), // Default: bottom center
    this.position = Offset.zero,
    this.rotation = 0.0,
    this.length = 50.0,
    this.attachedImages = const [],
  });

  Bone copyWith({
    String? name,
    String? parentName,
    Offset? pivot,
    Offset? position,
    double? rotation,
    double? length,
    List<String>? attachedImages,
  }) {
    return Bone(
      name: name ?? this.name,
      parentName: parentName ?? this.parentName,
      pivot: pivot ?? this.pivot,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      length: length ?? this.length,
      attachedImages: attachedImages ?? this.attachedImages,
    );
  }

  factory Bone.fromJson(Map<String, dynamic> json) {
    return Bone(
      name: json['name'] as String,
      parentName: json['parent'] as String?,
      pivot: json['pivot'] != null
          ? Offset(
              (json['pivot']['x'] as num).toDouble(),
              (json['pivot']['y'] as num).toDouble(),
            )
          : const Offset(0.5, 1.0),
      position: json['position'] != null
          ? Offset(
              (json['position']['x'] as num).toDouble(),
              (json['position']['y'] as num).toDouble(),
            )
          : Offset.zero,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      length: (json['length'] as num?)?.toDouble() ?? 50.0,
      attachedImages: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (parentName != null) 'parent': parentName,
        'pivot': {'x': pivot.dx, 'y': pivot.dy},
        'position': {'x': position.dx, 'y': position.dy},
        'rotation': rotation,
        'length': length,
        'images': attachedImages,
      };
}

/// A keyframe in an animation
class BoneKeyframe {
  final double time;  // Time in seconds
  final Map<String, BoneTransform> transforms;

  BoneKeyframe({
    required this.time,
    required this.transforms,
  });

  factory BoneKeyframe.fromJson(Map<String, dynamic> json) {
    final transforms = <String, BoneTransform>{};
    final transformsJson = json['transforms'] as Map<String, dynamic>? ?? {};
    transformsJson.forEach((key, value) {
      transforms[key] = BoneTransform.fromJson(value as Map<String, dynamic>);
    });
    return BoneKeyframe(
      time: (json['time'] as num).toDouble(),
      transforms: transforms,
    );
  }
}

/// Transform data for a bone at a keyframe
class BoneTransform {
  final double? rotation;
  final Offset? position;
  final double? scaleX;
  final double? scaleY;

  BoneTransform({
    this.rotation,
    this.position,
    this.scaleX,
    this.scaleY,
  });

  factory BoneTransform.fromJson(Map<String, dynamic> json) {
    return BoneTransform(
      rotation: (json['rotation'] as num?)?.toDouble(),
      position: json['position'] != null
          ? Offset(
              (json['position']['x'] as num).toDouble(),
              (json['position']['y'] as num).toDouble(),
            )
          : null,
      scaleX: (json['scaleX'] as num?)?.toDouble(),
      scaleY: (json['scaleY'] as num?)?.toDouble(),
    );
  }

  /// Lerp between two transforms
  static BoneTransform lerp(BoneTransform? a, BoneTransform? b, double t) {
    return BoneTransform(
      rotation: _lerpDouble(a?.rotation, b?.rotation, t),
      position: Offset.lerp(a?.position, b?.position, t),
      scaleX: _lerpDouble(a?.scaleX, b?.scaleY, t),
      scaleY: _lerpDouble(a?.scaleY, b?.scaleY, t),
    );
  }

  static double? _lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

/// An animation clip containing keyframes
class BoneAnimation {
  final String name;
  final double duration;
  final bool loop;
  final List<BoneKeyframe> keyframes;

  BoneAnimation({
    required this.name,
    required this.duration,
    this.loop = true,
    required this.keyframes,
  });

  factory BoneAnimation.fromJson(Map<String, dynamic> json) {
    return BoneAnimation(
      name: json['name'] as String,
      duration: (json['duration'] as num).toDouble(),
      loop: json['loop'] as bool? ?? true,
      keyframes: (json['keyframes'] as List<dynamic>)
          .map((e) => BoneKeyframe.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get interpolated transforms at a given time
  Map<String, BoneTransform> getTransformsAt(double time) {
    if (keyframes.isEmpty) return {};

    // Find surrounding keyframes
    BoneKeyframe? prev;
    BoneKeyframe? next;

    for (int i = 0; i < keyframes.length; i++) {
      if (keyframes[i].time <= time) {
        prev = keyframes[i];
      }
      if (keyframes[i].time >= time && next == null) {
        next = keyframes[i];
      }
    }

    prev ??= keyframes.first;
    next ??= keyframes.last;

    if (prev == next || prev.time == next.time) {
      return prev.transforms;
    }

    // Interpolate
    final t = (time - prev.time) / (next.time - prev.time);
    final result = <String, BoneTransform>{};

    final allBones = {...prev.transforms.keys, ...next.transforms.keys};
    for (final bone in allBones) {
      result[bone] = BoneTransform.lerp(
        prev.transforms[bone],
        next.transforms[bone],
        t,
      );
    }

    return result;
  }
}

/// Complete skeleton definition with bones and animations
class Skeleton {
  final String name;
  final List<Bone> bones;
  final Map<String, BoneAnimation> animations;
  final Size canvasSize;

  Skeleton({
    required this.name,
    required this.bones,
    required this.animations,
    this.canvasSize = const Size(512, 512),
  });

  factory Skeleton.fromJson(Map<String, dynamic> json) {
    final bonesJson = json['bones'] as List<dynamic>? ?? [];
    final animsJson = json['animations'] as Map<String, dynamic>? ?? {};

    final animations = <String, BoneAnimation>{};
    animsJson.forEach((key, value) {
      animations[key] = BoneAnimation.fromJson({
        'name': key,
        ...value as Map<String, dynamic>,
      });
    });

    return Skeleton(
      name: json['name'] as String? ?? 'skeleton',
      bones: bonesJson.map((e) => Bone.fromJson(e as Map<String, dynamic>)).toList(),
      animations: animations,
      canvasSize: json['canvasSize'] != null
          ? Size(
              (json['canvasSize']['width'] as num).toDouble(),
              (json['canvasSize']['height'] as num).toDouble(),
            )
          : const Size(512, 512),
    );
  }

  Bone? getBone(String name) {
    try {
      return bones.firstWhere((b) => b.name == name);
    } catch (e) {
      return null;
    }
  }

  List<Bone> getChildren(String parentName) {
    return bones.where((b) => b.parentName == parentName).toList();
  }

  Bone? get rootBone {
    try {
      return bones.firstWhere((b) => b.parentName == null);
    } catch (e) {
      return bones.isNotEmpty ? bones.first : null;
    }
  }
}

/// Widget that renders and animates a skeleton
class BoneAnimatorWidget extends StatefulWidget {
  final Skeleton skeleton;
  final String? currentAnimation;
  final String assetBasePath;
  final double scale;
  final bool showBones; // Debug: show bone structure

  const BoneAnimatorWidget({
    super.key,
    required this.skeleton,
    this.currentAnimation,
    required this.assetBasePath,
    this.scale = 1.0,
    this.showBones = false,
  });

  @override
  State<BoneAnimatorWidget> createState() => BoneAnimatorWidgetState();
}

class BoneAnimatorWidgetState extends State<BoneAnimatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Map<String, BoneTransform> _currentTransforms = {};
  String? _currentAnimName;

  // Dynamic image overrides for mouth shapes and eye states
  final Map<String, List<String>> _imageOverrides = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addListener(_updateAnimation);

    if (widget.currentAnimation != null) {
      playAnimation(widget.currentAnimation!);
    }
  }

  @override
  void didUpdateWidget(BoneAnimatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAnimation != oldWidget.currentAnimation &&
        widget.currentAnimation != null) {
      playAnimation(widget.currentAnimation!);
    }
  }

  void playAnimation(String name) {
    final anim = widget.skeleton.animations[name];
    if (anim == null) return;

    _currentAnimName = name;
    _controller.duration = Duration(
      milliseconds: (anim.duration * 1000).round(),
    );

    if (anim.loop) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0);
    }
  }

  void stopAnimation() {
    _controller.stop();
  }

  /// Set mouth shape for lip-sync (e.g., 'a', 'e', 'o', 'x')
  void setMouthShape(String shape) {
    setState(() {
      _imageOverrides['mouth'] = ['mouth_shapes/$shape.png'];
    });
  }

  /// Set eye state for blinking (e.g., 'open', 'half', 'closed')
  void setEyeState(String state) {
    setState(() {
      _imageOverrides['eyes'] = ['eyes/eyes_$state.png'];
    });
  }

  /// Clear all image overrides
  void clearOverrides() {
    setState(() {
      _imageOverrides.clear();
    });
  }

  void _updateAnimation() {
    if (_currentAnimName == null) return;

    final anim = widget.skeleton.animations[_currentAnimName];
    if (anim == null) return;

    final time = _controller.value * anim.duration;
    setState(() {
      _currentTransforms = anim.getTransformsAt(time);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.skeleton.canvasSize.width * widget.scale,
      height: widget.skeleton.canvasSize.height * widget.scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Render bones recursively from root
          if (widget.skeleton.rootBone != null)
            _buildBoneTree(widget.skeleton.rootBone!, Offset.zero, 0),
        ],
      ),
    );
  }

  Widget _buildBoneTree(Bone bone, Offset parentPosition, double parentRotation) {
    final transform = _currentTransforms[bone.name];

    // Calculate this bone's world transform
    final rotation = parentRotation + (transform?.rotation ?? bone.rotation);
    final localPos = transform?.position ?? bone.position;

    // Rotate local position by parent rotation
    final rotatedPos = _rotatePoint(localPos, parentRotation);
    final worldPos = parentPosition + rotatedPos;

    // Build children
    final children = widget.skeleton.getChildren(bone.name);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Render attached images (use overrides if available)
        for (final imagePath in (_imageOverrides[bone.name] ?? bone.attachedImages))
          Positioned(
            left: worldPos.dx * widget.scale,
            top: worldPos.dy * widget.scale,
            child: Transform(
              alignment: Alignment(
                bone.pivot.dx * 2 - 1,
                bone.pivot.dy * 2 - 1,
              ),
              transform: Matrix4.identity()
                ..rotateZ(rotation)
                ..scale(
                  transform?.scaleX ?? 1.0,
                  transform?.scaleY ?? 1.0,
                ),
              child: Image.asset(
                '${widget.assetBasePath}/$imagePath',
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),

        // Debug: show bone
        if (widget.showBones)
          Positioned(
            left: worldPos.dx * widget.scale,
            top: worldPos.dy * widget.scale,
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.topLeft,
              child: Container(
                width: bone.length * widget.scale,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

        // Render children
        for (final child in children)
          _buildBoneTree(child, worldPos, rotation),
      ],
    );
  }

  Offset _rotatePoint(Offset point, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      point.dx * cos - point.dy * sin,
      point.dx * sin + point.dy * cos,
    );
  }
}

/// Helper to load skeleton from JSON asset
Future<Skeleton> loadSkeleton(String assetPath) async {
  final jsonString = await rootBundle.loadString(assetPath);
  final json = jsonDecode(jsonString) as Map<String, dynamic>;
  return Skeleton.fromJson(json);
}
