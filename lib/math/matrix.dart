// lib/math/matrix.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'vector3.dart';

class Matrix {
  final List<double> storage;

  Matrix(this.storage);

  factory Matrix.identity() {
    final s = List<double>.filled(16, 0.0);
    s[0] = s[5] = s[10] = s[15] = 1.0;
    return Matrix(s);
  }

  Matrix4 toMatrix4() => Matrix4.fromFloat64List(Float64List.fromList(storage));

  void setIdentity() {
    for (int i = 0; i < 16; i++) {
      storage[i] = 0;
    }
    storage[0] = storage[5] = storage[10] = storage[15] = 1;
  }

  Matrix multiply(Matrix other) {
    Matrix m = Matrix(List.filled(16, 0.0));
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        for (int k = 0; k < 4; k++) {
          m.storage[i * 4 + j] += storage[i * 4 + k] * other.storage[k * 4 + j];
        }
      }
    }
    return m;
  }

  void translate(double tx, double ty, double tz) {
    storage[12] += tx * storage[0] + ty * storage[4] + tz * storage[8];
    storage[13] += tx * storage[1] + ty * storage[5] + tz * storage[9];
    storage[14] += tx * storage[2] + ty * storage[6] + tz * storage[10];
  }

  void rotate(double radians, double x, double y, double z) {
    final c = cos(radians);
    final s = sin(radians);
    final oc = 1 - c;

    final xx = x * x * oc, xy = x * y * oc, xz = x * z * oc;
    final yy = y * y * oc, yz = y * z * oc, zz = z * z * oc;
    final xs = x * s, ys = y * s, zs = z * s;

    final r00 = xx + c, r01 = xy + zs, r02 = xz - ys;
    final r10 = xy - zs, r11 = yy + c, r12 = yz + xs;
    final r20 = xz + ys, r21 = yz - xs, r22 = zz + c;

    final a0 = storage[0], a1 = storage[1], a2 = storage[2];
    final a4 = storage[4], a5 = storage[5], a6 = storage[6];
    final a8 = storage[8], a9 = storage[9], a10 = storage[10];

    storage[0] = r00 * a0 + r01 * a4 + r02 * a8;
    storage[1] = r00 * a1 + r01 * a5 + r02 * a9;
    storage[2] = r00 * a2 + r01 * a6 + r02 * a10;

    storage[4] = r10 * a0 + r11 * a4 + r12 * a8;
    storage[5] = r10 * a1 + r11 * a5 + r12 * a9;
    storage[6] = r10 * a2 + r11 * a6 + r12 * a10;

    storage[8] = r20 * a0 + r21 * a4 + r22 * a8;
    storage[9] = r20 * a1 + r21 * a5 + r22 * a9;
    storage[10] = r20 * a2 + r21 * a6 + r22 * a10;
  }

  void scale(double sx, double sy, double sz) {
    storage[0] *= sx;
    storage[4] *= sy;
    storage[8] *= sz;
    storage[1] *= sx;
    storage[5] *= sy;
    storage[9] *= sz;
    storage[2] *= sx;
    storage[6] *= sy;
    storage[10] *= sz;
  }
}

extension MatrixExt on Matrix {
  Vec3 get right => Vec3(storage[0], storage[1], storage[2]);
  Vec3 get up => Vec3(storage[4], storage[5], storage[6]);
  Vec3 get forward => Vec3(storage[8], storage[9], storage[10]);
}
