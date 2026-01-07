// vector2.dart - 2D vector math
// 100% original IP for WFL animation system

import 'dart:math' as math;

/// 2D Vector for positions, velocities, UVs
class Vector2 {
  double x;
  double y;

  Vector2(this.x, this.y);

  factory Vector2.zero() => Vector2(0, 0);
  factory Vector2.one() => Vector2(1, 1);
  factory Vector2.unitX() => Vector2(1, 0);
  factory Vector2.unitY() => Vector2(0, 1);
  factory Vector2.all(double v) => Vector2(v, v);

  /// From angle in radians
  factory Vector2.fromAngle(double radians, [double length = 1]) =>
      Vector2(math.cos(radians) * length, math.sin(radians) * length);

  // Accessors
  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;
  double get angle => math.atan2(y, x);

  // Setters
  set length(double value) {
    final l = length;
    if (l > 0) {
      final scale = value / l;
      x *= scale;
      y *= scale;
    }
  }

  // Operations returning new Vector2
  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);
  Vector2 operator -(Vector2 other) => Vector2(x - other.x, y - other.y);
  Vector2 operator *(double scalar) => Vector2(x * scalar, y * scalar);
  Vector2 operator /(double scalar) => Vector2(x / scalar, y / scalar);
  Vector2 operator -() => Vector2(-x, -y);

  /// Component-wise multiply
  Vector2 scale(Vector2 other) => Vector2(x * other.x, y * other.y);

  /// Dot product
  double dot(Vector2 other) => x * other.x + y * other.y;

  /// Cross product (returns scalar in 2D - z component of 3D cross)
  double cross(Vector2 other) => x * other.y - y * other.x;

  /// Normalized copy
  Vector2 normalized() {
    final l = length;
    return l > 0 ? this / l : Vector2.zero();
  }

  /// Normalize in place
  void normalize() {
    final l = length;
    if (l > 0) {
      x /= l;
      y /= l;
    }
  }

  /// Perpendicular vector (rotated 90 degrees counter-clockwise)
  Vector2 perpendicular() => Vector2(-y, x);

  /// Reflect across normal
  Vector2 reflect(Vector2 normal) {
    final d = 2 * dot(normal);
    return Vector2(x - d * normal.x, y - d * normal.y);
  }

  /// Linear interpolation
  Vector2 lerp(Vector2 other, double t) => Vector2(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
      );

  /// Distance to another vector
  double distanceTo(Vector2 other) => (this - other).length;
  double distanceSquaredTo(Vector2 other) => (this - other).lengthSquared;

  /// Angle to another vector in radians
  double angleTo(Vector2 other) {
    final d = dot(other) / (length * other.length);
    return math.acos(d.clamp(-1.0, 1.0));
  }

  /// Signed angle to another vector
  double signedAngleTo(Vector2 other) {
    final a = angleTo(other);
    return cross(other) < 0 ? -a : a;
  }

  /// Rotate by angle in radians
  Vector2 rotated(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vector2(x * c - y * s, x * s + y * c);
  }

  /// Rotate in place
  void rotate(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    final nx = x * c - y * s;
    final ny = x * s + y * c;
    x = nx;
    y = ny;
  }

  /// Clamp components
  Vector2 clamped(double minVal, double maxVal) => Vector2(
        x.clamp(minVal, maxVal),
        y.clamp(minVal, maxVal),
      );

  /// Clamp length
  Vector2 clampedLength(double maxLength) {
    final l = length;
    if (l > maxLength) {
      return this * (maxLength / l);
    }
    return Vector2(x, y);
  }

  /// Absolute value
  Vector2 abs() => Vector2(x.abs(), y.abs());

  /// Floor components
  Vector2 floor() => Vector2(x.floorToDouble(), y.floorToDouble());

  /// Ceil components
  Vector2 ceil() => Vector2(x.ceilToDouble(), y.ceilToDouble());

  /// Round components
  Vector2 round() => Vector2(x.roundToDouble(), y.roundToDouble());

  /// Copy
  Vector2 clone() => Vector2(x, y);

  /// Set from another vector
  void setFrom(Vector2 other) {
    x = other.x;
    y = other.y;
  }

  /// Set components
  void setValues(double x, double y) {
    this.x = x;
    this.y = y;
  }

  /// To list
  List<double> toList() => [x, y];

  @override
  String toString() => 'Vector2($x, $y)';

  @override
  bool operator ==(Object other) =>
      other is Vector2 && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}
