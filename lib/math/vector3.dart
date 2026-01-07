// lib/math/vector3.dart
import 'dart:math';

class Vec3 {
  double x, y, z;

  Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 v) => Vec3(x + v.x, y + v.y, z + v.z);
  Vec3 operator -(Vec3 v) => Vec3(x - v.x, y - v.y, z - v.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator /(double s) => Vec3(x / s, y / s, z / s);

  double dot(Vec3 v) => x * v.x + y * v.y + z * v.z;

  Vec3 cross(Vec3 v) => Vec3(
        y * v.z - z * v.y,
        z * v.x - x * v.z,
        x * v.y - y * v.x,
      );

  Vec3 normalized() {
    final len = length;
    return len != 0 ? Vec3(x / len, y / len, z / len) : Vec3.zero;
  }

  double get length => sqrt(x * x + y * y + z * z);
  double get lengthSquared => x * x + y * y + z * z;

  /// Linear interpolation between this and other
  Vec3 lerp(Vec3 other, double t) => Vec3(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
        z + (other.z - z) * t,
      );

  /// Copy this vector
  Vec3 clone() => Vec3(x, y, z);

  /// Set from another vector
  void setFrom(Vec3 other) {
    x = other.x;
    y = other.y;
    z = other.z;
  }

  Map<String, double> toMap() => {'x': x, 'y': y, 'z': z};

  static Vec3 fromMap(Map<String, dynamic> map) =>
      Vec3(map['x'] as double, map['y'] as double, map['z'] as double);

  static Vec3 get zero => Vec3(0, 0, 0);
  static Vec3 get one => Vec3(1, 1, 1);
  static Vec3 get up => Vec3(0, 1, 0);
  static Vec3 get forward => Vec3(0, 0, 1);
  static Vec3 get right => Vec3(1, 0, 0);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}
