// lib/math/transform.dart
import 'dart:math';
import 'vector3.dart';
import 'matrix.dart';
import 'quaternion.dart';

class Transform {
  Vec3 position = Vec3.zero;
  Quaternion rotation = Quaternion.identity();
  Vec3 scale = Vec3(1, 1, 1);

  final Matrix _matrix = Matrix(List.filled(16, 0.0));

  Transform() {
    _matrix.setIdentity();
  }

  Matrix get matrix {
    _matrix.setIdentity();
    _matrix.translate(position.x, position.y, position.z);

    final axis = rotation.axis();
    final angle = rotation.angle();
    if (angle != 0) {
      _matrix.rotate(angle, axis.x, axis.y, axis.z);
    }

    _matrix.scale(scale.x, scale.y, scale.z);
    return _matrix;
  }

  void translateBy(Vec3 v) => position = position + v;

  void rotateBy(double angle, Vec3 axis) {
    rotation = Quaternion.axisAngle(axis, angle) * rotation;
  }

  void setRotation(double angle, Vec3 axis) {
    rotation = Quaternion.axisAngle(axis, angle);
  }

  void scaleBy(Vec3 s) {
    scale = Vec3(scale.x * s.x, scale.y * s.y, scale.z * s.z);
  }

  void setScale(Vec3 s) => scale = s;

  void lookAt(Vec3 target, Vec3 up) {
    final z = (position - target).normalized();
    final x = up.cross(z).normalized();
    final y = z.cross(x);

    _matrix.setIdentity();
    _matrix.storage[0] = x.x;
    _matrix.storage[1] = x.y;
    _matrix.storage[2] = x.z;
    _matrix.storage[4] = y.x;
    _matrix.storage[5] = y.y;
    _matrix.storage[6] = y.z;
    _matrix.storage[8] = z.x;
    _matrix.storage[9] = z.y;
    _matrix.storage[10] = z.z;
    _matrix.storage[12] = -x.dot(position);
    _matrix.storage[13] = -y.dot(position);
    _matrix.storage[14] = -z.dot(position);
  }

  /// Decompose a matrix into position, rotation, and scale
  static Transform decompose(Matrix m) {
    final transform = Transform();

    // Extract translation
    transform.position = Vec3(m.storage[12], m.storage[13], m.storage[14]);

    // Extract scale
    final sx = Vec3(m.storage[0], m.storage[1], m.storage[2]).length;
    final sy = Vec3(m.storage[4], m.storage[5], m.storage[6]).length;
    final sz = Vec3(m.storage[8], m.storage[9], m.storage[10]).length;
    transform.scale = Vec3(sx, sy, sz);

    // Extract rotation (remove scale from rotation matrix)
    final r00 = m.storage[0] / sx;
    final r01 = m.storage[1] / sx;
    final r02 = m.storage[2] / sx;
    final r10 = m.storage[4] / sy;
    final r11 = m.storage[5] / sy;
    final r12 = m.storage[6] / sy;
    final r20 = m.storage[8] / sz;
    final r21 = m.storage[9] / sz;
    final r22 = m.storage[10] / sz;

    // Convert rotation matrix to quaternion
    final trace = r00 + r11 + r22;
    double qw, qx, qy, qz;

    if (trace > 0) {
      final s = 0.5 / sqrt(trace + 1.0);
      qw = 0.25 / s;
      qx = (r21 - r12) * s;
      qy = (r02 - r20) * s;
      qz = (r10 - r01) * s;
    } else if (r00 > r11 && r00 > r22) {
      final s = 2.0 * sqrt(1.0 + r00 - r11 - r22);
      qw = (r21 - r12) / s;
      qx = 0.25 * s;
      qy = (r01 + r10) / s;
      qz = (r02 + r20) / s;
    } else if (r11 > r22) {
      final s = 2.0 * sqrt(1.0 + r11 - r00 - r22);
      qw = (r02 - r20) / s;
      qx = (r01 + r10) / s;
      qy = 0.25 * s;
      qz = (r12 + r21) / s;
    } else {
      final s = 2.0 * sqrt(1.0 + r22 - r00 - r11);
      qw = (r10 - r01) / s;
      qx = (r02 + r20) / s;
      qy = (r12 + r21) / s;
      qz = 0.25 * s;
    }

    transform.rotation = Quaternion(qx, qy, qz, qw).normalized();
    return transform;
  }
}
