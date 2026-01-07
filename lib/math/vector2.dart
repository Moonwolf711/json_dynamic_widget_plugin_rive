// lib/math/vector2.dart
import 'dart:math';

class Vec2 {
  double x, y;

  Vec2(this.x, this.y);

  Vec2 operator +(Vec2 v) => Vec2(x + v.x, y + v.y);
  Vec2 operator -(Vec2 v) => Vec2(x - v.x, y - v.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);

  double dot(Vec2 v) => x * v.x + y * v.y;

  Vec2 normalized() {
    final len = length;
    return len != 0 ? Vec2(x / len, y / len) : Vec2(0, 0);
  }

  double get length => sqrt(x * x + y * y);

  Vec2 setLength(double l) => normalized() * l;

  Vec2 perpendicular() => Vec2(-y, x);

  static Vec2 get zero => Vec2(0, 0);

  @override
  String toString() => 'Vec2($x, $y)';
}
