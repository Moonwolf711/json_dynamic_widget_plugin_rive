// matrix.dart - 4x4 matrix math
// 100% original IP for WFL animation system

import 'dart:math' as math;
import 'dart:typed_data';
import 'vector3.dart';
import 'vector4.dart';
import 'quaternion.dart';

/// 4x4 Matrix for 3D transformations
/// Column-major storage (OpenGL/Flutter convention)
class Matrix4x4 {
  final Float64List _m;

  Matrix4x4() : _m = Float64List(16) {
    setIdentity();
  }

  Matrix4x4.zero() : _m = Float64List(16);

  Matrix4x4.fromList(List<double> values)
      : _m = Float64List.fromList(values.length >= 16
            ? values.sublist(0, 16)
            : [...values, ...List.filled(16 - values.length, 0.0)]);

  Matrix4x4._internal(this._m);

  /// Identity matrix
  factory Matrix4x4.identity() => Matrix4x4();

  /// Translation matrix
  factory Matrix4x4.translation(double x, double y, double z) {
    final m = Matrix4x4();
    m._m[12] = x;
    m._m[13] = y;
    m._m[14] = z;
    return m;
  }

  /// Translation from Vector3
  factory Matrix4x4.translationVector(Vector3 v) =>
      Matrix4x4.translation(v.x, v.y, v.z);

  /// Scale matrix
  factory Matrix4x4.scale(double x, double y, double z) {
    final m = Matrix4x4.zero();
    m._m[0] = x;
    m._m[5] = y;
    m._m[10] = z;
    m._m[15] = 1;
    return m;
  }

  /// Uniform scale
  factory Matrix4x4.uniformScale(double s) => Matrix4x4.scale(s, s, s);

  /// Rotation around X axis
  factory Matrix4x4.rotationX(double radians) {
    final m = Matrix4x4();
    final c = math.cos(radians);
    final s = math.sin(radians);
    m._m[5] = c;
    m._m[6] = s;
    m._m[9] = -s;
    m._m[10] = c;
    return m;
  }

  /// Rotation around Y axis
  factory Matrix4x4.rotationY(double radians) {
    final m = Matrix4x4();
    final c = math.cos(radians);
    final s = math.sin(radians);
    m._m[0] = c;
    m._m[2] = -s;
    m._m[8] = s;
    m._m[10] = c;
    return m;
  }

  /// Rotation around Z axis
  factory Matrix4x4.rotationZ(double radians) {
    final m = Matrix4x4();
    final c = math.cos(radians);
    final s = math.sin(radians);
    m._m[0] = c;
    m._m[1] = s;
    m._m[4] = -s;
    m._m[5] = c;
    return m;
  }

  /// Rotation around arbitrary axis
  factory Matrix4x4.rotationAxis(Vector3 axis, double radians) {
    final a = axis.normalized();
    final c = math.cos(radians);
    final s = math.sin(radians);
    final t = 1 - c;

    final m = Matrix4x4.zero();
    m._m[0] = t * a.x * a.x + c;
    m._m[1] = t * a.x * a.y + s * a.z;
    m._m[2] = t * a.x * a.z - s * a.y;
    m._m[4] = t * a.x * a.y - s * a.z;
    m._m[5] = t * a.y * a.y + c;
    m._m[6] = t * a.y * a.z + s * a.x;
    m._m[8] = t * a.x * a.z + s * a.y;
    m._m[9] = t * a.y * a.z - s * a.x;
    m._m[10] = t * a.z * a.z + c;
    m._m[15] = 1;
    return m;
  }

  /// From quaternion rotation
  factory Matrix4x4.fromQuaternion(Quaternion q) {
    final n = q.normalized();
    final x = n.x, y = n.y, z = n.z, w = n.w;

    final m = Matrix4x4.zero();
    m._m[0] = 1 - 2 * (y * y + z * z);
    m._m[1] = 2 * (x * y + z * w);
    m._m[2] = 2 * (x * z - y * w);
    m._m[4] = 2 * (x * y - z * w);
    m._m[5] = 1 - 2 * (x * x + z * z);
    m._m[6] = 2 * (y * z + x * w);
    m._m[8] = 2 * (x * z + y * w);
    m._m[9] = 2 * (y * z - x * w);
    m._m[10] = 1 - 2 * (x * x + y * y);
    m._m[15] = 1;
    return m;
  }

  /// Look-at matrix (camera)
  factory Matrix4x4.lookAt(Vector3 eye, Vector3 target, Vector3 up) {
    final z = (eye - target).normalized();
    final x = up.cross(z).normalized();
    final y = z.cross(x);

    final m = Matrix4x4.zero();
    m._m[0] = x.x;
    m._m[1] = y.x;
    m._m[2] = z.x;
    m._m[4] = x.y;
    m._m[5] = y.y;
    m._m[6] = z.y;
    m._m[8] = x.z;
    m._m[9] = y.z;
    m._m[10] = z.z;
    m._m[12] = -x.dot(eye);
    m._m[13] = -y.dot(eye);
    m._m[14] = -z.dot(eye);
    m._m[15] = 1;
    return m;
  }

  /// Perspective projection
  factory Matrix4x4.perspective(
      double fovY, double aspect, double near, double far) {
    final f = 1 / math.tan(fovY / 2);
    final nf = 1 / (near - far);

    final m = Matrix4x4.zero();
    m._m[0] = f / aspect;
    m._m[5] = f;
    m._m[10] = (far + near) * nf;
    m._m[11] = -1;
    m._m[14] = 2 * far * near * nf;
    return m;
  }

  /// Orthographic projection
  factory Matrix4x4.orthographic(
      double left, double right, double bottom, double top, double near, double far) {
    final m = Matrix4x4.zero();
    m._m[0] = 2 / (right - left);
    m._m[5] = 2 / (top - bottom);
    m._m[10] = -2 / (far - near);
    m._m[12] = -(right + left) / (right - left);
    m._m[13] = -(top + bottom) / (top - bottom);
    m._m[14] = -(far + near) / (far - near);
    m._m[15] = 1;
    return m;
  }

  // Element access
  double operator [](int index) => _m[index];
  void operator []=(int index, double value) => _m[index] = value;

  double at(int row, int col) => _m[col * 4 + row];
  void setAt(int row, int col, double value) => _m[col * 4 + row] = value;

  // Column access
  Vector4 getColumn(int col) =>
      Vector4(_m[col * 4], _m[col * 4 + 1], _m[col * 4 + 2], _m[col * 4 + 3]);

  void setColumn(int col, Vector4 v) {
    _m[col * 4] = v.x;
    _m[col * 4 + 1] = v.y;
    _m[col * 4 + 2] = v.z;
    _m[col * 4 + 3] = v.w;
  }

  // Row access
  Vector4 getRow(int row) =>
      Vector4(_m[row], _m[row + 4], _m[row + 8], _m[row + 12]);

  void setRow(int row, Vector4 v) {
    _m[row] = v.x;
    _m[row + 4] = v.y;
    _m[row + 8] = v.z;
    _m[row + 12] = v.w;
  }

  /// Set to identity
  void setIdentity() {
    _m.fillRange(0, 16, 0);
    _m[0] = _m[5] = _m[10] = _m[15] = 1;
  }

  /// Set to zero
  void setZero() => _m.fillRange(0, 16, 0);

  /// Translation component
  Vector3 get translation => Vector3(_m[12], _m[13], _m[14]);
  set translation(Vector3 v) {
    _m[12] = v.x;
    _m[13] = v.y;
    _m[14] = v.z;
  }

  /// Matrix multiplication
  Matrix4x4 operator *(Matrix4x4 other) {
    final result = Matrix4x4.zero();
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 4; row++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += at(row, k) * other.at(k, col);
        }
        result.setAt(row, col, sum);
      }
    }
    return result;
  }

  /// Transform Vector4
  Vector4 transform(Vector4 v) => Vector4(
        _m[0] * v.x + _m[4] * v.y + _m[8] * v.z + _m[12] * v.w,
        _m[1] * v.x + _m[5] * v.y + _m[9] * v.z + _m[13] * v.w,
        _m[2] * v.x + _m[6] * v.y + _m[10] * v.z + _m[14] * v.w,
        _m[3] * v.x + _m[7] * v.y + _m[11] * v.z + _m[15] * v.w,
      );

  /// Transform Vector3 as point (w=1)
  Vector3 transformPoint(Vector3 v) {
    final w = _m[3] * v.x + _m[7] * v.y + _m[11] * v.z + _m[15];
    return Vector3(
      (_m[0] * v.x + _m[4] * v.y + _m[8] * v.z + _m[12]) / w,
      (_m[1] * v.x + _m[5] * v.y + _m[9] * v.z + _m[13]) / w,
      (_m[2] * v.x + _m[6] * v.y + _m[10] * v.z + _m[14]) / w,
    );
  }

  /// Transform Vector3 as direction (w=0)
  Vector3 transformDirection(Vector3 v) => Vector3(
        _m[0] * v.x + _m[4] * v.y + _m[8] * v.z,
        _m[1] * v.x + _m[5] * v.y + _m[9] * v.z,
        _m[2] * v.x + _m[6] * v.y + _m[10] * v.z,
      );

  /// Transpose
  Matrix4x4 transposed() {
    final result = Matrix4x4.zero();
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        result.setAt(i, j, at(j, i));
      }
    }
    return result;
  }

  /// Determinant
  double get determinant {
    final a = _m[0], b = _m[1], c = _m[2], d = _m[3];
    final e = _m[4], f = _m[5], g = _m[6], h = _m[7];
    final i = _m[8], j = _m[9], k = _m[10], l = _m[11];
    final m = _m[12], n = _m[13], o = _m[14], p = _m[15];

    return a * (f * (k * p - l * o) - g * (j * p - l * n) + h * (j * o - k * n)) -
        b * (e * (k * p - l * o) - g * (i * p - l * m) + h * (i * o - k * m)) +
        c * (e * (j * p - l * n) - f * (i * p - l * m) + h * (i * n - j * m)) -
        d * (e * (j * o - k * n) - f * (i * o - k * m) + g * (i * n - j * m));
  }

  /// Inverse (returns null if singular)
  Matrix4x4? inverse() {
    final det = determinant;
    if (det.abs() < 1e-10) return null;

    final a = _m[0], b = _m[1], c = _m[2], d = _m[3];
    final e = _m[4], f = _m[5], g = _m[6], h = _m[7];
    final i = _m[8], j = _m[9], k = _m[10], l = _m[11];
    final m = _m[12], n = _m[13], o = _m[14], p = _m[15];

    final invDet = 1 / det;
    final result = Matrix4x4.zero();

    result._m[0] = (f * (k * p - l * o) - g * (j * p - l * n) + h * (j * o - k * n)) * invDet;
    result._m[1] = -(b * (k * p - l * o) - c * (j * p - l * n) + d * (j * o - k * n)) * invDet;
    result._m[2] = (b * (g * p - h * o) - c * (f * p - h * n) + d * (f * o - g * n)) * invDet;
    result._m[3] = -(b * (g * l - h * k) - c * (f * l - h * j) + d * (f * k - g * j)) * invDet;
    result._m[4] = -(e * (k * p - l * o) - g * (i * p - l * m) + h * (i * o - k * m)) * invDet;
    result._m[5] = (a * (k * p - l * o) - c * (i * p - l * m) + d * (i * o - k * m)) * invDet;
    result._m[6] = -(a * (g * p - h * o) - c * (e * p - h * m) + d * (e * o - g * m)) * invDet;
    result._m[7] = (a * (g * l - h * k) - c * (e * l - h * i) + d * (e * k - g * i)) * invDet;
    result._m[8] = (e * (j * p - l * n) - f * (i * p - l * m) + h * (i * n - j * m)) * invDet;
    result._m[9] = -(a * (j * p - l * n) - b * (i * p - l * m) + d * (i * n - j * m)) * invDet;
    result._m[10] = (a * (f * p - h * n) - b * (e * p - h * m) + d * (e * n - f * m)) * invDet;
    result._m[11] = -(a * (f * l - h * j) - b * (e * l - h * i) + d * (e * j - f * i)) * invDet;
    result._m[12] = -(e * (j * o - k * n) - f * (i * o - k * m) + g * (i * n - j * m)) * invDet;
    result._m[13] = (a * (j * o - k * n) - b * (i * o - k * m) + c * (i * n - j * m)) * invDet;
    result._m[14] = -(a * (f * o - g * n) - b * (e * o - g * m) + c * (e * n - f * m)) * invDet;
    result._m[15] = (a * (f * k - g * j) - b * (e * k - g * i) + c * (e * j - f * i)) * invDet;

    return result;
  }

  /// Copy
  Matrix4x4 clone() => Matrix4x4._internal(Float64List.fromList(_m));

  /// Raw data access
  Float64List get storage => _m;

  @override
  String toString() => 'Matrix4x4(\n'
      '  ${_m[0]}, ${_m[4]}, ${_m[8]}, ${_m[12]}\n'
      '  ${_m[1]}, ${_m[5]}, ${_m[9]}, ${_m[13]}\n'
      '  ${_m[2]}, ${_m[6]}, ${_m[10]}, ${_m[14]}\n'
      '  ${_m[3]}, ${_m[7]}, ${_m[11]}, ${_m[15]}\n)';
}
