// quaternion.dart - Quaternion math for rotations
// 100% original IP for WFL animation system

import 'dart:math' as math;
import 'vector3.dart';

/// Quaternion for smooth 3D rotations (no gimbal lock)
class Quaternion {
  double x;
  double y;
  double z;
  double w;

  Quaternion(this.x, this.y, this.z, this.w);

  /// Identity quaternion (no rotation)
  factory Quaternion.identity() => Quaternion(0, 0, 0, 1);

  /// From axis-angle
  factory Quaternion.axisAngle(Vector3 axis, double radians) {
    final halfAngle = radians / 2;
    final s = math.sin(halfAngle);
    final a = axis.normalized();
    return Quaternion(a.x * s, a.y * s, a.z * s, math.cos(halfAngle));
  }

  /// From Euler angles (ZYX order - yaw, pitch, roll)
  factory Quaternion.euler(double yaw, double pitch, double roll) {
    final cy = math.cos(yaw * 0.5);
    final sy = math.sin(yaw * 0.5);
    final cp = math.cos(pitch * 0.5);
    final sp = math.sin(pitch * 0.5);
    final cr = math.cos(roll * 0.5);
    final sr = math.sin(roll * 0.5);

    return Quaternion(
      sr * cp * cy - cr * sp * sy,
      cr * sp * cy + sr * cp * sy,
      cr * cp * sy - sr * sp * cy,
      cr * cp * cy + sr * sp * sy,
    );
  }

  /// From rotation that takes v1 to v2
  factory Quaternion.fromTo(Vector3 v1, Vector3 v2) {
    final a = v1.normalized();
    final b = v2.normalized();
    final dot = a.dot(b);

    if (dot > 0.999999) {
      return Quaternion.identity();
    }
    if (dot < -0.999999) {
      // 180 degree rotation - pick arbitrary perpendicular axis
      var axis = Vector3.unitX().cross(a);
      if (axis.lengthSquared < 0.01) {
        axis = Vector3.unitY().cross(a);
      }
      return Quaternion.axisAngle(axis.normalized(), math.pi);
    }

    final axis = a.cross(b);
    return Quaternion(axis.x, axis.y, axis.z, 1 + dot).normalized();
  }

  /// Look rotation (direction + up)
  factory Quaternion.lookRotation(Vector3 forward, [Vector3? up]) {
    up ??= Vector3.unitY();
    final f = forward.normalized();
    final r = up.cross(f).normalized();
    final u = f.cross(r);

    final m00 = r.x, m01 = r.y, m02 = r.z;
    final m10 = u.x, m11 = u.y, m12 = u.z;
    final m20 = f.x, m21 = f.y, m22 = f.z;

    final trace = m00 + m11 + m22;

    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1);
      return Quaternion(
        (m12 - m21) * s,
        (m20 - m02) * s,
        (m01 - m10) * s,
        0.25 / s,
      );
    } else if (m00 > m11 && m00 > m22) {
      final s = 2 * math.sqrt(1 + m00 - m11 - m22);
      return Quaternion(
        0.25 * s,
        (m01 + m10) / s,
        (m02 + m20) / s,
        (m12 - m21) / s,
      );
    } else if (m11 > m22) {
      final s = 2 * math.sqrt(1 + m11 - m00 - m22);
      return Quaternion(
        (m01 + m10) / s,
        0.25 * s,
        (m12 + m21) / s,
        (m20 - m02) / s,
      );
    } else {
      final s = 2 * math.sqrt(1 + m22 - m00 - m11);
      return Quaternion(
        (m02 + m20) / s,
        (m12 + m21) / s,
        0.25 * s,
        (m01 - m10) / s,
      );
    }
  }

  // Accessors
  double get length => math.sqrt(x * x + y * y + z * z + w * w);
  double get lengthSquared => x * x + y * y + z * z + w * w;

  /// Rotation angle in radians
  double get angle => 2 * math.acos(w.clamp(-1.0, 1.0));

  /// Rotation axis
  Vector3 get axis {
    final sinHalf = math.sqrt(1 - w * w);
    if (sinHalf < 0.0001) {
      return Vector3.unitX();
    }
    return Vector3(x / sinHalf, y / sinHalf, z / sinHalf);
  }

  /// To Euler angles (ZYX order)
  Vector3 get eulerAngles {
    final sinr = 2 * (w * x + y * z);
    final cosr = 1 - 2 * (x * x + y * y);
    final roll = math.atan2(sinr, cosr);

    final sinp = 2 * (w * y - z * x);
    final pitch = sinp.abs() >= 1
        ? math.pi / 2 * sinp.sign
        : math.asin(sinp);

    final siny = 2 * (w * z + x * y);
    final cosy = 1 - 2 * (y * y + z * z);
    final yaw = math.atan2(siny, cosy);

    return Vector3(roll, pitch, yaw);
  }

  // Operations
  Quaternion operator +(Quaternion other) =>
      Quaternion(x + other.x, y + other.y, z + other.z, w + other.w);

  Quaternion operator -(Quaternion other) =>
      Quaternion(x - other.x, y - other.y, z - other.z, w - other.w);

  Quaternion operator *(double scalar) =>
      Quaternion(x * scalar, y * scalar, z * scalar, w * scalar);

  Quaternion operator /(double scalar) =>
      Quaternion(x / scalar, y / scalar, z / scalar, w / scalar);

  Quaternion operator -() => Quaternion(-x, -y, -z, -w);

  /// Quaternion multiplication (combines rotations)
  Quaternion multiply(Quaternion other) => Quaternion(
        w * other.x + x * other.w + y * other.z - z * other.y,
        w * other.y - x * other.z + y * other.w + z * other.x,
        w * other.z + x * other.y - y * other.x + z * other.w,
        w * other.w - x * other.x - y * other.y - z * other.z,
      );

  /// Dot product
  double dot(Quaternion other) =>
      x * other.x + y * other.y + z * other.z + w * other.w;

  /// Normalized copy
  Quaternion normalized() {
    final l = length;
    return l > 0 ? this / l : Quaternion.identity();
  }

  /// Normalize in place
  void normalize() {
    final l = length;
    if (l > 0) {
      x /= l;
      y /= l;
      z /= l;
      w /= l;
    }
  }

  /// Conjugate (inverse for unit quaternions)
  Quaternion conjugate() => Quaternion(-x, -y, -z, w);

  /// Inverse
  Quaternion inverse() {
    final l2 = lengthSquared;
    if (l2 < 0.0001) return Quaternion.identity();
    return Quaternion(-x / l2, -y / l2, -z / l2, w / l2);
  }

  /// Rotate a vector
  Vector3 rotate(Vector3 v) {
    final qv = Quaternion(v.x, v.y, v.z, 0);
    final result = multiply(qv).multiply(conjugate());
    return Vector3(result.x, result.y, result.z);
  }

  /// Linear interpolation (not ideal for rotations but fast)
  Quaternion lerp(Quaternion other, double t) =>
      (this * (1 - t) + other * t).normalized();

  /// Spherical linear interpolation (smooth rotation interpolation)
  Quaternion slerp(Quaternion other, double t) {
    var dot = this.dot(other).clamp(-1.0, 1.0);

    // If dot is negative, negate one to take shorter path
    var target = other;
    if (dot < 0) {
      target = -other;
      dot = -dot;
    }

    // If very close, use lerp to avoid division by zero
    if (dot > 0.9995) {
      return lerp(target, t);
    }

    final theta0 = math.acos(dot);
    final theta = theta0 * t;
    final sinTheta = math.sin(theta);
    final sinTheta0 = math.sin(theta0);

    final s0 = math.cos(theta) - dot * sinTheta / sinTheta0;
    final s1 = sinTheta / sinTheta0;

    return this * s0 + target * s1;
  }

  /// Angle between two quaternions
  double angleTo(Quaternion other) {
    final d = dot(other).abs().clamp(0.0, 1.0);
    return 2 * math.acos(d);
  }

  /// Forward direction (local Z axis)
  Vector3 get forward => rotate(Vector3.unitZ());

  /// Right direction (local X axis)
  Vector3 get right => rotate(Vector3.unitX());

  /// Up direction (local Y axis)
  Vector3 get up => rotate(Vector3.unitY());

  /// Copy
  Quaternion clone() => Quaternion(x, y, z, w);

  /// Set from another quaternion
  void setFrom(Quaternion other) {
    x = other.x;
    y = other.y;
    z = other.z;
    w = other.w;
  }

  @override
  String toString() => 'Quaternion($x, $y, $z, $w)';

  @override
  bool operator ==(Object other) =>
      other is Quaternion &&
      x == other.x &&
      y == other.y &&
      z == other.z &&
      w == other.w;

  @override
  int get hashCode => Object.hash(x, y, z, w);
}
