// lib/math/bone.dart
import 'transform.dart';
import 'vector3.dart';
import 'quaternion.dart';

class Bone {
  final String name;
  final Transform local = Transform();
  final Transform global = Transform();

  Bone? parent;
  final List<Bone> children = [];

  Bone(this.name);

  /// Add a child bone
  void addChild(Bone child) {
    child.parent = this;
    children.add(child);
  }

  /// Remove a child bone
  void removeChild(Bone child) {
    child.parent = null;
    children.remove(child);
  }

  /// Update global transform based on parent chain
  void update() {
    if (parent != null) {
      // Combine parent's global with our local
      global.position = parent!.global.position +
          parent!.global.rotation.rotateVector(local.position);
      global.rotation = parent!.global.rotation * local.rotation;
      global.scale = Vec3(
        parent!.global.scale.x * local.scale.x,
        parent!.global.scale.y * local.scale.y,
        parent!.global.scale.z * local.scale.z,
      );
    } else {
      // Root bone: global = local
      global.setFrom(local);
    }

    // Update children recursively
    for (final child in children) {
      child.update();
    }
  }

  /// Find bone by name in hierarchy
  Bone? find(String boneName) {
    if (name == boneName) return this;
    for (final child in children) {
      final found = child.find(boneName);
      if (found != null) return found;
    }
    return null;
  }

  /// Get all bones in hierarchy as flat list
  List<Bone> flatten() {
    final result = <Bone>[this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }

  /// Serialize bone hierarchy
  Map<String, dynamic> toMap() => {
        'name': name,
        'local': local.toMap(),
        'children': children.map((c) => c.toMap()).toList(),
      };

  /// Deserialize bone hierarchy
  factory Bone.fromMap(Map<String, dynamic> map) {
    final bone = Bone(map['name'] as String);
    if (map['local'] != null) {
      bone.local.setFrom(Transform.fromMap(map['local'] as Map<String, dynamic>));
    }
    if (map['children'] != null) {
      for (final childMap in map['children'] as List) {
        bone.addChild(Bone.fromMap(childMap as Map<String, dynamic>));
      }
    }
    return bone;
  }

  @override
  String toString() => 'Bone($name)';
}
