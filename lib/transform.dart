import 'package:vector_math/vector_math_64.dart';

/// 3D transform describing a model's position, rotation, and scale.
/// Uses vector_math types for GPU-optimized operations.
class Transform {
  Vector3 position;
  Quaternion rotation;
  Vector3 scale;

  Transform({
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
  })  : position = position ?? Vector3.zero(),
        rotation = rotation ?? Quaternion.identity(),
        scale = scale ?? Vector3.all(1.0);

  /// The composed model matrix for this transform.
  Matrix4 get matrix => Matrix4.compose(position, rotation, scale);

  /// Orients this transform to face [target] using [up] as the reference up.
  ///
  /// This is a **model-space** operation: it updates [rotation] while keeping
  /// [position] intact. It does **not** return a view matrix or apply the
  /// `-basis.dot(position)` translation used for cameras. Use a camera/view
  /// helper instead of calling this on a model if you need a view matrix.
  void lookAt(Vector3 target, {Vector3? up}) {
    final upDirection = up ?? Vector3(0.0, 1.0, 0.0);
    final forward = target - position;
    if (forward.length2 == 0.0) {
      return;
    }

    forward.normalize();
    var right = upDirection.cross(forward);
    if (right.length2 == 0.0) {
      final fallbackUp = forward.x.abs() < 0.999
          ? Vector3(1.0, 0.0, 0.0)
          : Vector3(0.0, 1.0, 0.0);
      right = fallbackUp.cross(forward);
    }

    right.normalize();
    final trueUp = forward.cross(right);

    final basis = Matrix3.zero()
      ..setColumn(0, right)
      ..setColumn(1, trueUp)
      ..setColumn(2, forward);
    rotation = Quaternion.fromRotation(basis);
  }

  /// Linear interpolation between transforms
  Transform lerp(Transform other, double t) {
    return Transform(
      position: Vector3.zero()
        ..setFrom(position)
        ..lerp(other.position, t),
      rotation: Quaternion.identity()
        ..setFrom(rotation)
        ..slerp(other.rotation, t),
      scale: Vector3.zero()
        ..setFrom(scale)
        ..lerp(other.scale, t),
    );
  }

  /// Create a copy of this transform
  Transform clone() => Transform(
        position: position.clone(),
        rotation: rotation.clone(),
        scale: scale.clone(),
      );

  /// Copy values from another transform
  void setFrom(Transform other) {
    position.setFrom(other.position);
    rotation.setFrom(other.rotation);
    scale.setFrom(other.scale);
  }

  /// Serialize to map
  Map<String, dynamic> toMap() => {
        'position': {'x': position.x, 'y': position.y, 'z': position.z},
        'rotation': {
          'x': rotation.x,
          'y': rotation.y,
          'z': rotation.z,
          'w': rotation.w
        },
        'scale': {'x': scale.x, 'y': scale.y, 'z': scale.z},
      };

  /// Deserialize from map
  factory Transform.fromMap(Map<String, dynamic> map) {
    final t = Transform();
    if (map['position'] != null) {
      final p = map['position'] as Map<String, dynamic>;
      t.position = Vector3(
        (p['x'] as num).toDouble(),
        (p['y'] as num).toDouble(),
        (p['z'] as num).toDouble(),
      );
    }
    if (map['rotation'] != null) {
      final r = map['rotation'] as Map<String, dynamic>;
      t.rotation = Quaternion(
        (r['x'] as num).toDouble(),
        (r['y'] as num).toDouble(),
        (r['z'] as num).toDouble(),
        (r['w'] as num).toDouble(),
      );
    }
    if (map['scale'] != null) {
      final s = map['scale'] as Map<String, dynamic>;
      t.scale = Vector3(
        (s['x'] as num).toDouble(),
        (s['y'] as num).toDouble(),
        (s['z'] as num).toDouble(),
      );
    }
    return t;
  }
}
