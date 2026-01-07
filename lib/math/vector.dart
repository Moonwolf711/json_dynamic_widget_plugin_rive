// vector.dart - Vector base utilities and extensions
// 100% original IP for WFL animation system

import 'dart:math' as math;
import 'vector2.dart';
import 'vector3.dart';
import 'vector4.dart';

/// Vector utilities and factory methods
class VectorUtils {
  VectorUtils._();

  /// Create Vector2 from list
  static Vector2 vec2FromList(List<double> list) =>
      Vector2(list.isNotEmpty ? list[0] : 0, list.length > 1 ? list[1] : 0);

  /// Create Vector3 from list
  static Vector3 vec3FromList(List<double> list) => Vector3(
        list.isNotEmpty ? list[0] : 0,
        list.length > 1 ? list[1] : 0,
        list.length > 2 ? list[2] : 0,
      );

  /// Create Vector4 from list
  static Vector4 vec4FromList(List<double> list) => Vector4(
        list.isNotEmpty ? list[0] : 0,
        list.length > 1 ? list[1] : 0,
        list.length > 2 ? list[2] : 0,
        list.length > 3 ? list[3] : 0,
      );

  /// Random Vector2 in range
  static Vector2 randomVec2({double min = 0, double max = 1, math.Random? rng}) {
    rng ??= math.Random();
    final range = max - min;
    return Vector2(
      min + rng.nextDouble() * range,
      min + rng.nextDouble() * range,
    );
  }

  /// Random Vector3 in range
  static Vector3 randomVec3({double min = 0, double max = 1, math.Random? rng}) {
    rng ??= math.Random();
    final range = max - min;
    return Vector3(
      min + rng.nextDouble() * range,
      min + rng.nextDouble() * range,
      min + rng.nextDouble() * range,
    );
  }

  /// Random unit Vector2 (on unit circle)
  static Vector2 randomUnitVec2({math.Random? rng}) {
    rng ??= math.Random();
    final angle = rng.nextDouble() * 2 * math.pi;
    return Vector2(math.cos(angle), math.sin(angle));
  }

  /// Random unit Vector3 (on unit sphere)
  static Vector3 randomUnitVec3({math.Random? rng}) {
    rng ??= math.Random();
    // Use spherical coordinates for uniform distribution
    final theta = rng.nextDouble() * 2 * math.pi;
    final phi = math.acos(2 * rng.nextDouble() - 1);
    return Vector3(
      math.sin(phi) * math.cos(theta),
      math.sin(phi) * math.sin(theta),
      math.cos(phi),
    );
  }

  /// Random Vector3 in unit sphere (not just on surface)
  static Vector3 randomInSphere({math.Random? rng}) {
    rng ??= math.Random();
    final u = randomUnitVec3(rng: rng);
    final r = math.pow(rng.nextDouble(), 1 / 3).toDouble();
    return u * r;
  }

  /// Barycentric interpolation
  static Vector3 barycentric(
    Vector3 p1,
    Vector3 p2,
    Vector3 p3,
    double u,
    double v,
  ) {
    final w = 1 - u - v;
    return p1 * w + p2 * u + p3 * v;
  }

  /// Catmull-Rom spline interpolation
  static Vector3 catmullRom(
    Vector3 p0,
    Vector3 p1,
    Vector3 p2,
    Vector3 p3,
    double t,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;

    return (p1 * 2 +
            (p2 - p0) * t +
            (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
            (-p0 + p1 * 3 - p2 * 3 + p3) * t3) *
        0.5;
  }

  /// Bezier curve interpolation (cubic)
  static Vector3 bezier(
    Vector3 p0,
    Vector3 p1,
    Vector3 p2,
    Vector3 p3,
    double t,
  ) {
    final u = 1 - t;
    final u2 = u * u;
    final u3 = u2 * u;
    final t2 = t * t;
    final t3 = t2 * t;

    return p0 * u3 + p1 * (3 * u2 * t) + p2 * (3 * u * t2) + p3 * t3;
  }

  /// Hermite interpolation
  static Vector3 hermite(
    Vector3 p0,
    Vector3 m0,
    Vector3 p1,
    Vector3 m1,
    double t,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;

    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;

    return p0 * h00 + m0 * h10 + p1 * h01 + m1 * h11;
  }

  /// Smooth step (Hermite interpolation between 0 and 1)
  static double smoothStep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Smoother step (C2 continuous)
  static double smootherStep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * t * (t * (t * 6 - 15) + 10);
  }
}

/// Extensions for List<double> to Vector conversion
extension ListToVector on List<double> {
  Vector2 toVector2() => VectorUtils.vec2FromList(this);
  Vector3 toVector3() => VectorUtils.vec3FromList(this);
  Vector4 toVector4() => VectorUtils.vec4FromList(this);
}
