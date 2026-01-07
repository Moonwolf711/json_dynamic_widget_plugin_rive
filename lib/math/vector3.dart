// vector3.dart - 3D vector math
// 100% original IP for WFL animation system

import 'dart:math' as math;
import 'vector2.dart';

/// 3D Vector for positions, normals, colors (RGB)
class Vector3 {
  double x;
  double y;
  double z;

  Vector3(this.x, this.y, this.z);

  factory Vector3.zero() => Vector3(0, 0, 0);
  factory Vector3.one() => Vector3(1, 1, 1);
  factory Vector3.unitX() => Vector3(1, 0, 0);
  factory Vector3.unitY() => Vector3(0, 1, 0);
  factory Vector3.unitZ() => Vector3(0, 0, 1);
  factory Vector3.all(double v) => Vector3(v, v, v);

  /// From Vector2 with z=0
  factory Vector3.fromVector2(Vector2 v, [double z = 0]) => Vector3(v.x, v.y, z);

  /// From spherical coordinates (radius, theta, phi)
  factory Vector3.fromSpherical(double r, double theta, double phi) => Vector3(
        r * math.sin(phi) * math.cos(theta),
        r * math.sin(phi) * math.sin(theta),
        r * math.cos(phi),
      );

  // Swizzles
  Vector2 get xy => Vector2(x, y);
  Vector2 get xz => Vector2(x, z);
  Vector2 get yz => Vector2(y, z);

  // Accessors
  double get length => math.sqrt(x * x + y * y + z * z);
  double get lengthSquared => x * x + y * y + z * z;

  // Setters
  set length(double value) {
    final l = length;
    if (l > 0) {
      final scale = value / l;
      x *= scale;
      y *= scale;
      z *= scale;
    }
  }

  // Operations
  Vector3 operator +(Vector3 other) =>
      Vector3(x + other.x, y + other.y, z + other.z);
  Vector3 operator -(Vector3 other) =>
      Vector3(x - other.x, y - other.y, z - other.z);
  Vector3 operator *(double scalar) => Vector3(x * scalar, y * scalar, z * scalar);
  Vector3 operator /(double scalar) => Vector3(x / scalar, y / scalar, z / scalar);
  Vector3 operator -() => Vector3(-x, -y, -z);

  /// Component-wise multiply
  Vector3 scale(Vector3 other) => Vector3(x * other.x, y * other.y, z * other.z);

  /// Dot product
  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;

  /// Cross product
  Vector3 cross(Vector3 other) => Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  /// Normalized copy
  Vector3 normalized() {
    final l = length;
    return l > 0 ? this / l : Vector3.zero();
  }

  /// Normalize in place
  void normalize() {
    final l = length;
    if (l > 0) {
      x /= l;
      y /= l;
      z /= l;
    }
  }

  /// Reflect across normal
  Vector3 reflect(Vector3 normal) {
    final d = 2 * dot(normal);
    return Vector3(x - d * normal.x, y - d * normal.y, z - d * normal.z);
  }

  /// Linear interpolation
  Vector3 lerp(Vector3 other, double t) => Vector3(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
        z + (other.z - z) * t,
      );

  /// Spherical linear interpolation (for directions)
  Vector3 slerp(Vector3 other, double t) {
    final dot = this.dot(other).clamp(-1.0, 1.0);
    final theta = math.acos(dot) * t;
    final relative = (other - this * dot).normalized();
    return this * math.cos(theta) + relative * math.sin(theta);
  }

  /// Distance to another vector
  double distanceTo(Vector3 other) => (this - other).length;
  double distanceSquaredTo(Vector3 other) => (this - other).lengthSquared;

  /// Angle to another vector in radians
  double angleTo(Vector3 other) {
    final d = dot(other) / (length * other.length);
    return math.acos(d.clamp(-1.0, 1.0));
  }

  /// Project onto another vector
  Vector3 projectOnto(Vector3 other) {
    final d = dot(other) / other.lengthSquared;
    return other * d;
  }

  /// Reject from another vector (perpendicular component)
  Vector3 rejectFrom(Vector3 other) => this - projectOnto(other);

  /// Clamp components
  Vector3 clamped(double minVal, double maxVal) => Vector3(
        x.clamp(minVal, maxVal),
        y.clamp(minVal, maxVal),
        z.clamp(minVal, maxVal),
      );

  /// Clamp length
  Vector3 clampedLength(double maxLength) {
    final l = length;
    if (l > maxLength) {
      return this * (maxLength / l);
    }
    return Vector3(x, y, z);
  }

  /// Absolute value
  Vector3 abs() => Vector3(x.abs(), y.abs(), z.abs());

  /// Floor components
  Vector3 floor() =>
      Vector3(x.floorToDouble(), y.floorToDouble(), z.floorToDouble());

  /// Ceil components
  Vector3 ceil() =>
      Vector3(x.ceilToDouble(), y.ceilToDouble(), z.ceilToDouble());

  /// Round components
  Vector3 round() =>
      Vector3(x.roundToDouble(), y.roundToDouble(), z.roundToDouble());

  /// Min of each component
  Vector3 min(Vector3 other) => Vector3(
        math.min(x, other.x),
        math.min(y, other.y),
        math.min(z, other.z),
      );

  /// Max of each component
  Vector3 max(Vector3 other) => Vector3(
        math.max(x, other.x),
        math.max(y, other.y),
        math.max(z, other.z),
      );

  /// Copy
  Vector3 clone() => Vector3(x, y, z);

  /// Set from another vector
  void setFrom(Vector3 other) {
    x = other.x;
    y = other.y;
    z = other.z;
  }

  /// Set components
  void setValues(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  /// To list
  List<double> toList() => [x, y, z];

  @override
  String toString() => 'Vector3($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      other is Vector3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}
