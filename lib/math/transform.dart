// transform.dart - 3D Transform with position, rotation, scale
// 100% original IP for WFL animation system

import 'vector3.dart';
import 'quaternion.dart';
import 'matrix.dart';

/// 3D Transform combining position, rotation, and scale
/// Suitable for scene graph hierarchies and bone animation
class Transform3D {
  Vector3 position;
  Quaternion rotation;
  Vector3 scale;

  Transform3D({
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
  })  : position = position ?? Vector3.zero(),
        rotation = rotation ?? Quaternion.identity(),
        scale = scale ?? Vector3.one();

  /// Identity transform
  factory Transform3D.identity() => Transform3D();

  /// From position only
  factory Transform3D.translation(double x, double y, double z) =>
      Transform3D(position: Vector3(x, y, z));

  /// From position vector
  factory Transform3D.translationVector(Vector3 v) =>
      Transform3D(position: v.clone());

  /// From rotation only
  factory Transform3D.fromRotation(Quaternion q) =>
      Transform3D(rotation: q.clone());

  /// From Euler angles
  factory Transform3D.euler(double yaw, double pitch, double roll) =>
      Transform3D(rotation: Quaternion.euler(yaw, pitch, roll));

  /// From uniform scale
  factory Transform3D.uniformScale(double s) =>
      Transform3D(scale: Vector3.all(s));

  /// From matrix (decomposes TRS)
  factory Transform3D.fromMatrix(Matrix4x4 m) {
    // Extract translation
    final pos = m.translation;

    // Extract scale (length of each basis vector)
    final sx = Vector3(m[0], m[1], m[2]).length;
    final sy = Vector3(m[4], m[5], m[6]).length;
    final sz = Vector3(m[8], m[9], m[10]).length;
    final scl = Vector3(sx, sy, sz);

    // Extract rotation (normalize basis vectors)
    final rotMat = Matrix4x4.zero();
    if (sx > 0) {
      rotMat[0] = m[0] / sx;
      rotMat[1] = m[1] / sx;
      rotMat[2] = m[2] / sx;
    }
    if (sy > 0) {
      rotMat[4] = m[4] / sy;
      rotMat[5] = m[5] / sy;
      rotMat[6] = m[6] / sy;
    }
    if (sz > 0) {
      rotMat[8] = m[8] / sz;
      rotMat[9] = m[9] / sz;
      rotMat[10] = m[10] / sz;
    }
    rotMat[15] = 1;

    // Convert rotation matrix to quaternion
    final rot = _matrixToQuaternion(rotMat);

    return Transform3D(position: pos, rotation: rot, scale: scl);
  }

  static Quaternion _matrixToQuaternion(Matrix4x4 m) {
    final trace = m[0] + m[5] + m[10];

    if (trace > 0) {
      final s = 0.5 / (trace + 1).sqrt();
      return Quaternion(
        (m[6] - m[9]) * s,
        (m[8] - m[2]) * s,
        (m[1] - m[4]) * s,
        0.25 / s,
      );
    } else if (m[0] > m[5] && m[0] > m[10]) {
      final s = 2 * (1 + m[0] - m[5] - m[10]).sqrt();
      return Quaternion(
        0.25 * s,
        (m[4] + m[1]) / s,
        (m[8] + m[2]) / s,
        (m[6] - m[9]) / s,
      );
    } else if (m[5] > m[10]) {
      final s = 2 * (1 + m[5] - m[0] - m[10]).sqrt();
      return Quaternion(
        (m[4] + m[1]) / s,
        0.25 * s,
        (m[9] + m[6]) / s,
        (m[8] - m[2]) / s,
      );
    } else {
      final s = 2 * (1 + m[10] - m[0] - m[5]).sqrt();
      return Quaternion(
        (m[8] + m[2]) / s,
        (m[9] + m[6]) / s,
        0.25 * s,
        (m[1] - m[4]) / s,
      );
    }
  }

  /// Convert to 4x4 matrix (TRS order: scale, then rotate, then translate)
  Matrix4x4 toMatrix() {
    final t = Matrix4x4.translationVector(position);
    final r = Matrix4x4.fromQuaternion(rotation);
    final s = Matrix4x4.scale(scale.x, scale.y, scale.z);
    return t * r * s;
  }

  /// Local forward direction
  Vector3 get forward => rotation.forward;

  /// Local right direction
  Vector3 get right => rotation.right;

  /// Local up direction
  Vector3 get up => rotation.up;

  /// Euler angles (yaw, pitch, roll)
  Vector3 get eulerAngles => rotation.eulerAngles;
  set eulerAngles(Vector3 angles) {
    rotation = Quaternion.euler(angles.z, angles.y, angles.x);
  }

  /// Transform a point from local to world space
  Vector3 transformPoint(Vector3 point) {
    return position + rotation.rotate(point.scale(scale));
  }

  /// Transform a direction from local to world space (ignores position)
  Vector3 transformDirection(Vector3 dir) {
    return rotation.rotate(dir);
  }

  /// Inverse transform a point from world to local space
  Vector3 inverseTransformPoint(Vector3 point) {
    final invRotation = rotation.inverse();
    final localPoint = invRotation.rotate(point - position);
    return Vector3(
      scale.x != 0 ? localPoint.x / scale.x : 0,
      scale.y != 0 ? localPoint.y / scale.y : 0,
      scale.z != 0 ? localPoint.z / scale.z : 0,
    );
  }

  /// Inverse transform a direction from world to local space
  Vector3 inverseTransformDirection(Vector3 dir) {
    return rotation.inverse().rotate(dir);
  }

  /// Look at a target point
  void lookAt(Vector3 target, [Vector3? worldUp]) {
    worldUp ??= Vector3.unitY();
    final direction = (target - position).normalized();
    rotation = Quaternion.lookRotation(direction, worldUp);
  }

  /// Rotate around an axis
  void rotateAround(Vector3 axis, double angle) {
    rotation = Quaternion.axisAngle(axis, angle).multiply(rotation);
  }

  /// Rotate around local X axis
  void rotateX(double angle) {
    rotateAround(right, angle);
  }

  /// Rotate around local Y axis
  void rotateY(double angle) {
    rotateAround(up, angle);
  }

  /// Rotate around local Z axis
  void rotateZ(double angle) {
    rotateAround(forward, angle);
  }

  /// Translate in world space
  void translate(Vector3 translation) {
    position = position + translation;
  }

  /// Translate in local space
  void translateLocal(Vector3 translation) {
    position = position + transformDirection(translation);
  }

  /// Linear interpolation
  Transform3D lerp(Transform3D other, double t) => Transform3D(
        position: position.lerp(other.position, t),
        rotation: rotation.slerp(other.rotation, t),
        scale: scale.lerp(other.scale, t),
      );

  /// Combine two transforms (this * other)
  Transform3D combine(Transform3D other) {
    return Transform3D(
      position: transformPoint(other.position),
      rotation: rotation.multiply(other.rotation),
      scale: scale.scale(other.scale),
    );
  }

  /// Inverse transform
  Transform3D inverse() {
    final invRotation = rotation.inverse();
    final invScale = Vector3(
      scale.x != 0 ? 1 / scale.x : 0,
      scale.y != 0 ? 1 / scale.y : 0,
      scale.z != 0 ? 1 / scale.z : 0,
    );
    final invPosition = invRotation.rotate(-position).scale(invScale);

    return Transform3D(
      position: invPosition,
      rotation: invRotation,
      scale: invScale,
    );
  }

  /// Reset to identity
  void setIdentity() {
    position = Vector3.zero();
    rotation = Quaternion.identity();
    scale = Vector3.one();
  }

  /// Copy
  Transform3D clone() => Transform3D(
        position: position.clone(),
        rotation: rotation.clone(),
        scale: scale.clone(),
      );

  /// Set from another transform
  void setFrom(Transform3D other) {
    position.setFrom(other.position);
    rotation.setFrom(other.rotation);
    scale.setFrom(other.scale);
  }

  @override
  String toString() => 'Transform3D(\n'
      '  position: $position\n'
      '  rotation: $rotation\n'
      '  scale: $scale\n)';

  @override
  bool operator ==(Object other) =>
      other is Transform3D &&
      position == other.position &&
      rotation == other.rotation &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(position, rotation, scale);
}
