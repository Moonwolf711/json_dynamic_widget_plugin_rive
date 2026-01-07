// lib/math/flutter.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'vector3.dart';
import 'matrix.dart';

extension Vec3Flutter on Vec3 {
  Offset toOffset() => Offset(x, y);
  Matrix4 toMatrix4() => Matrix4.translationValues(x, y, z);
}

extension Matrix4Flutter on Matrix4 {
  Matrix toMatrix() => Matrix(Float64List.fromList(storage));
}

extension MatrixFlutter on Matrix {
  Matrix4 toFlutterMatrix4() => Matrix4.fromFloat64List(Float64List.fromList(storage));
}
