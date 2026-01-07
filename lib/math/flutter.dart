// lib/math/flutter.dart
// Bridge between pure Dart math library and vector_math/Flutter types
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'vector2.dart';
import 'vector3.dart';
import 'vector4.dart';
import 'matrix.dart';
import 'quaternion.dart';
import 'transform.dart' as math;
import '../transform.dart' as core;

// ==================== Vec2 <-> Offset ====================

extension Vec2Flutter on Vec2 {
  Offset toOffset() => Offset(x, y);
}

extension OffsetToVec2 on Offset {
  Vec2 toVec2() => Vec2(dx, dy);
}

// ==================== Vec3 <-> Vector3 ====================

extension Vec3ToVectorMath on Vec3 {
  /// Convert to vector_math Vector3
  vm.Vector3 toVector3() => vm.Vector3(x, y, z);

  /// Convert to Flutter Offset (ignores z)
  Offset toOffset() => Offset(x, y);

  /// Create translation Matrix4
  vm.Matrix4 toTranslationMatrix4() => vm.Matrix4.translationValues(x, y, z);
}

extension Vector3ToVec3 on vm.Vector3 {
  /// Convert to pure Dart Vec3
  Vec3 toVec3() => Vec3(x, y, z);
}

// ==================== Vec4 <-> Vector4 ====================

extension Vec4ToVectorMath on Vec4 {
  vm.Vector4 toVector4() => vm.Vector4(x, y, z, w);
}

extension Vector4ToVec4 on vm.Vector4 {
  Vec4 toVec4() => Vec4(x, y, z, w);
}

// ==================== Quaternion <-> Quaternion ====================

extension QuaternionToVectorMath on Quaternion {
  /// Convert to vector_math Quaternion
  vm.Quaternion toVmQuaternion() => vm.Quaternion(x, y, z, w);
}

extension VmQuaternionToQuaternion on vm.Quaternion {
  /// Convert to pure Dart Quaternion
  Quaternion toQuaternion() => Quaternion(x, y, z, w);
}

// ==================== Matrix <-> Matrix4 ====================

extension MatrixToVectorMath on Matrix {
  /// Convert to vector_math Matrix4
  vm.Matrix4 toMatrix4() => vm.Matrix4.fromFloat64List(Float64List.fromList(storage));
}

extension Matrix4ToMatrix on vm.Matrix4 {
  /// Convert to pure Dart Matrix
  Matrix toMatrix() => Matrix(Float64List.fromList(storage));
}

// ==================== Transform <-> Transform ====================

extension MathTransformToCore on math.Transform {
  /// Convert pure Dart Transform to vector_math-based Transform
  core.Transform toCoreTransform() => core.Transform(
        position: position.toVector3(),
        rotation: rotation.toVmQuaternion(),
        scale: scale.toVector3(),
      );
}

extension CoreTransformToMath on core.Transform {
  /// Convert vector_math-based Transform to pure Dart Transform
  math.Transform toMathTransform() {
    final t = math.Transform();
    t.position = position.toVec3();
    t.rotation = rotation.toQuaternion();
    t.scale = scale.toVec3();
    return t;
  }
}

// ==================== Matrix4 decompose ====================

extension Matrix4Decompose on vm.Matrix4 {
  /// Decompose into core.Transform (position, rotation, scale)
  core.Transform decompose() {
    final position = vm.Vector3.zero();
    final rotation = vm.Quaternion.identity();
    final scale = vm.Vector3.zero();

    // Extract translation
    position.setValues(storage[12], storage[13], storage[14]);

    // Extract scale
    final sx = vm.Vector3(storage[0], storage[1], storage[2]).length;
    final sy = vm.Vector3(storage[4], storage[5], storage[6]).length;
    final sz = vm.Vector3(storage[8], storage[9], storage[10]).length;
    scale.setValues(sx, sy, sz);

    // Extract rotation (remove scale from basis vectors)
    if (sx > 0 && sy > 0 && sz > 0) {
      final m = vm.Matrix3.zero();
      m.setColumn(0, vm.Vector3(storage[0] / sx, storage[1] / sx, storage[2] / sx));
      m.setColumn(1, vm.Vector3(storage[4] / sy, storage[5] / sy, storage[6] / sy));
      m.setColumn(2, vm.Vector3(storage[8] / sz, storage[9] / sz, storage[10] / sz));
      rotation.setFromRotation(m);
    }

    return core.Transform(
      position: position,
      rotation: rotation,
      scale: scale,
    );
  }
}
