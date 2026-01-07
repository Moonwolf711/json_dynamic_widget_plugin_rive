// lib/math/quaternion.dart
import 'dart:math';
import 'vector3.dart';

class Quaternion {
  double x, y, z, w;

  Quaternion(this.x, this.y, this.z, this.w);

  factory Quaternion.identity() => Quaternion(0, 0, 0, 1);

  factory Quaternion.axisAngle(Vec3 axis, double angle) {
    final halfAngle = angle / 2;
    final s = sin(halfAngle);
    final normalized = axis.normalized();
    return Quaternion(
      normalized.x * s,
      normalized.y * s,
      normalized.z * s,
      cos(halfAngle),
    );
  }

  factory Quaternion.euler(double pitch, double yaw, double roll) {
    final cy = cos(yaw * 0.5);
    final sy = sin(yaw * 0.5);
    final cp = cos(pitch * 0.5);
    final sp = sin(pitch * 0.5);
    final cr = cos(roll * 0.5);
    final sr = sin(roll * 0.5);

    return Quaternion(
      sr * cp * cy - cr * sp * sy,
      cr * sp * cy + sr * cp * sy,
      cr * cp * sy - sr * sp * cy,
      cr * cp * cy + sr * sp * sy,
    );
  }

  Quaternion operator *(Quaternion q) => Quaternion(
        w * q.x + x * q.w + y * q.z - z * q.y,
        w * q.y - x * q.z + y * q.w + z * q.x,
        w * q.z + x * q.y - y * q.x + z * q.w,
        w * q.w - x * q.x - y * q.y - z * q.z,
      );

  double get length => sqrt(x * x + y * y + z * z + w * w);

  Quaternion normalized() {
    final len = length;
    return len != 0
        ? Quaternion(x / len, y / len, z / len, w / len)
        : Quaternion.identity();
  }

  Quaternion conjugate() => Quaternion(-x, -y, -z, w);

  Quaternion inverse() {
    final lenSq = x * x + y * y + z * z + w * w;
    return Quaternion(-x / lenSq, -y / lenSq, -z / lenSq, w / lenSq);
  }

  /// Returns the angle in radians
  double angle() => 2 * acos(w.clamp(-1.0, 1.0));

  /// Returns the axis of rotation
  Vec3 axis() {
    final s = sqrt(1 - w * w);
    if (s < 0.001) {
      return Vec3(1, 0, 0);
    }
    return Vec3(x / s, y / s, z / s);
  }

  /// Returns axis-angle representation as Vec3 (axis * angle)
  Vec3 toAxisAngle() {
    final a = angle();
    final ax = axis();
    return Vec3(ax.x * a, ax.y * a, ax.z * a);
  }

  /// Rotate a vector by this quaternion
  Vec3 rotateVector(Vec3 v) {
    final qv = Quaternion(v.x, v.y, v.z, 0);
    final result = this * qv * conjugate();
    return Vec3(result.x, result.y, result.z);
  }

  /// Spherical linear interpolation
  static Quaternion slerp(Quaternion a, Quaternion b, double t) {
    var dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;

    // If dot is negative, negate one quaternion to take the shorter path
    if (dot < 0) {
      b = Quaternion(-b.x, -b.y, -b.z, -b.w);
      dot = -dot;
    }

    if (dot > 0.9995) {
      // Linear interpolation for very close quaternions
      return Quaternion(
        a.x + t * (b.x - a.x),
        a.y + t * (b.y - a.y),
        a.z + t * (b.z - a.z),
        a.w + t * (b.w - a.w),
      ).normalized();
    }

    final theta0 = acos(dot);
    final theta = theta0 * t;
    final sinTheta = sin(theta);
    final sinTheta0 = sin(theta0);

    final s0 = cos(theta) - dot * sinTheta / sinTheta0;
    final s1 = sinTheta / sinTheta0;

    return Quaternion(
      s0 * a.x + s1 * b.x,
      s0 * a.y + s1 * b.y,
      s0 * a.z + s1 * b.z,
      s0 * a.w + s1 * b.w,
    );
  }

  @override
  String toString() => 'Quaternion($x, $y, $z, $w)';
}
