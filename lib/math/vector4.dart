// vector4.dart - 4D vector math
// 100% original IP for WFL animation system

import 'dart:math' as math;
import 'vector2.dart';
import 'vector3.dart';

/// 4D Vector for homogeneous coordinates, colors (RGBA), quaternions
class Vector4 {
  double x;
  double y;
  double z;
  double w;

  Vector4(this.x, this.y, this.z, this.w);

  factory Vector4.zero() => Vector4(0, 0, 0, 0);
  factory Vector4.one() => Vector4(1, 1, 1, 1);
  factory Vector4.unitX() => Vector4(1, 0, 0, 0);
  factory Vector4.unitY() => Vector4(0, 1, 0, 0);
  factory Vector4.unitZ() => Vector4(0, 0, 1, 0);
  factory Vector4.unitW() => Vector4(0, 0, 0, 1);
  factory Vector4.all(double v) => Vector4(v, v, v, v);

  /// From Vector3 with w=1 (point) or w=0 (direction)
  factory Vector4.fromVector3(Vector3 v, [double w = 1]) =>
      Vector4(v.x, v.y, v.z, w);

  /// From Vector2 with z=0, w=1
  factory Vector4.fromVector2(Vector2 v, [double z = 0, double w = 1]) =>
      Vector4(v.x, v.y, z, w);

  /// RGBA color (0-1 range)
  factory Vector4.rgba(double r, double g, double b, double a) =>
      Vector4(r, g, b, a);

  // Swizzles
  Vector2 get xy => Vector2(x, y);
  Vector3 get xyz => Vector3(x, y, z);
  Vector3 get rgb => Vector3(x, y, z);

  // Color accessors
  double get r => x;
  double get g => y;
  double get b => z;
  double get a => w;
  set r(double v) => x = v;
  set g(double v) => y = v;
  set b(double v) => z = v;
  set a(double v) => w = v;

  // Accessors
  double get length => math.sqrt(x * x + y * y + z * z + w * w);
  double get lengthSquared => x * x + y * y + z * z + w * w;

  // Setters
  set length(double value) {
    final l = length;
    if (l > 0) {
      final scale = value / l;
      x *= scale;
      y *= scale;
      z *= scale;
      w *= scale;
    }
  }

  // Operations
  Vector4 operator +(Vector4 other) =>
      Vector4(x + other.x, y + other.y, z + other.z, w + other.w);
  Vector4 operator -(Vector4 other) =>
      Vector4(x - other.x, y - other.y, z - other.z, w - other.w);
  Vector4 operator *(double scalar) =>
      Vector4(x * scalar, y * scalar, z * scalar, w * scalar);
  Vector4 operator /(double scalar) =>
      Vector4(x / scalar, y / scalar, z / scalar, w / scalar);
  Vector4 operator -() => Vector4(-x, -y, -z, -w);

  /// Component-wise multiply
  Vector4 scale(Vector4 other) =>
      Vector4(x * other.x, y * other.y, z * other.z, w * other.w);

  /// Dot product
  double dot(Vector4 other) =>
      x * other.x + y * other.y + z * other.z + w * other.w;

  /// Normalized copy
  Vector4 normalized() {
    final l = length;
    return l > 0 ? this / l : Vector4.zero();
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

  /// Linear interpolation
  Vector4 lerp(Vector4 other, double t) => Vector4(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
        z + (other.z - z) * t,
        w + (other.w - w) * t,
      );

  /// Distance to another vector
  double distanceTo(Vector4 other) => (this - other).length;
  double distanceSquaredTo(Vector4 other) => (this - other).lengthSquared;

  /// Perspective divide (homogeneous to Cartesian)
  Vector3 perspectiveDivide() {
    if (w == 0) return Vector3(x, y, z);
    return Vector3(x / w, y / w, z / w);
  }

  /// Clamp components
  Vector4 clamped(double minVal, double maxVal) => Vector4(
        x.clamp(minVal, maxVal),
        y.clamp(minVal, maxVal),
        z.clamp(minVal, maxVal),
        w.clamp(minVal, maxVal),
      );

  /// Absolute value
  Vector4 abs() => Vector4(x.abs(), y.abs(), z.abs(), w.abs());

  /// Floor components
  Vector4 floor() => Vector4(
        x.floorToDouble(),
        y.floorToDouble(),
        z.floorToDouble(),
        w.floorToDouble(),
      );

  /// Ceil components
  Vector4 ceil() => Vector4(
        x.ceilToDouble(),
        y.ceilToDouble(),
        z.ceilToDouble(),
        w.ceilToDouble(),
      );

  /// Round components
  Vector4 round() => Vector4(
        x.roundToDouble(),
        y.roundToDouble(),
        z.roundToDouble(),
        w.roundToDouble(),
      );

  /// Copy
  Vector4 clone() => Vector4(x, y, z, w);

  /// Set from another vector
  void setFrom(Vector4 other) {
    x = other.x;
    y = other.y;
    z = other.z;
    w = other.w;
  }

  /// Set components
  void setValues(double x, double y, double z, double w) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
  }

  /// To list
  List<double> toList() => [x, y, z, w];

  /// To ARGB int (for Flutter Color)
  int toArgb() {
    final ai = (a * 255).round().clamp(0, 255);
    final ri = (r * 255).round().clamp(0, 255);
    final gi = (g * 255).round().clamp(0, 255);
    final bi = (b * 255).round().clamp(0, 255);
    return (ai << 24) | (ri << 16) | (gi << 8) | bi;
  }

  /// From ARGB int
  factory Vector4.fromArgb(int argb) => Vector4(
        ((argb >> 16) & 0xFF) / 255.0,
        ((argb >> 8) & 0xFF) / 255.0,
        (argb & 0xFF) / 255.0,
        ((argb >> 24) & 0xFF) / 255.0,
      );

  @override
  String toString() => 'Vector4($x, $y, $z, $w)';

  @override
  bool operator ==(Object other) =>
      other is Vector4 &&
      x == other.x &&
      y == other.y &&
      z == other.z &&
      w == other.w;

  @override
  int get hashCode => Object.hash(x, y, z, w);
}
