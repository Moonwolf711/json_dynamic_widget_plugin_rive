// lib/math/vector4.dart
import 'dart:math';

class Vec4 {
  double x, y, z, w;

  Vec4(this.x, this.y, this.z, this.w);

  Vec4 operator +(Vec4 v) => Vec4(x + v.x, y + v.y, z + v.z, w + v.w);
  Vec4 operator -(Vec4 v) => Vec4(x - v.x, y - v.y, z - v.z, w - v.w);
  Vec4 operator *(double s) => Vec4(x * s, y * s, z * s, w * s);
  Vec4 operator /(double s) => Vec4(x / s, y / s, z / s, w / s);

  double dot(Vec4 v) => x * v.x + y * v.y + z * v.z + w * v.w;

  double get length => sqrt(x * x + y * y + z * z + w * w);

  Vec4 normalized() {
    final len = length;
    return len != 0 ? Vec4(x / len, y / len, z / len, w / len) : Vec4.zero;
  }

  static Vec4 get zero => Vec4(0, 0, 0, 0);

  @override
  String toString() => 'Vec4($x, $y, $z, $w)';
}
