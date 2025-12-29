// Bone Editor - Draw and control bones directly in Flutter
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

/// A single bone with position, rotation, and parent reference
class Bone {
  String id;
  String name;
  Offset position;      // Root position
  double length;
  double rotation;      // Degrees
  String? parentId;
  List<String> childIds;
  Color color;

  Bone({
    required this.id,
    required this.name,
    required this.position,
    this.length = 50,
    this.rotation = 0,
    this.parentId,
    List<String>? childIds,
    Color? color,
  }) : childIds = childIds ?? [],
       color = color ?? Colors.white;

  Offset get endPosition {
    final rad = rotation * pi / 180;
    return Offset(
      position.dx + cos(rad) * length,
      position.dy + sin(rad) * length,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'x': position.dx,
    'y': position.dy,
    'length': length,
    'rotation': rotation,
    'parentId': parentId,
    'childIds': childIds,
    'color': color.value,
  };

  factory Bone.fromJson(Map<String, dynamic> json) => Bone(
    id: json['id'],
    name: json['name'],
    position: Offset(json['x'], json['y']),
    length: json['length'],
    rotation: json['rotation'],
    parentId: json['parentId'],
    childIds: List<String>.from(json['childIds'] ?? []),
    color: Color(json['color'] ?? 0xFFFFFFFF),
  );
}

/// Skeleton containing all bones
class Skeleton {
  String name;
  Map<String, Bone> bones;

  Skeleton({required this.name, Map<String, Bone>? bones})
    : bones = bones ?? {};

  void addBone(Bone bone) {
    bones[bone.id] = bone;
    if (bone.parentId != null && bones.containsKey(bone.parentId)) {
      bones[bone.parentId]!.childIds.add(bone.id);
    }
  }

  void removeBone(String id) {
    final bone = bones[id];
    if (bone == null) return;

    // Remove from parent's children
    if (bone.parentId != null && bones.containsKey(bone.parentId)) {
      bones[bone.parentId]!.childIds.remove(id);
    }

    // Reparent children to this bone's parent
    for (final childId in bone.childIds) {
      if (bones.containsKey(childId)) {
        bones[childId]!.parentId = bone.parentId;
      }
    }

    bones.remove(id);
  }

  void rotateBone(String id, double angleDelta) {
    final bone = bones[id];
    if (bone == null) return;
    bone.rotation += angleDelta;
    _propagateRotation(id, angleDelta);
  }

  void setBoneRotation(String id, double angle) {
    final bone = bones[id];
    if (bone == null) return;
    final delta = angle - bone.rotation;
    bone.rotation = angle;
    _propagateRotation(id, delta);
  }

  void _propagateRotation(String parentId, double angleDelta) {
    final parent = bones[parentId];
    if (parent == null) return;

    for (final childId in parent.childIds) {
      final child = bones[childId];
      if (child == null) continue;

      // Rotate child around parent's end point
      final rad = angleDelta * pi / 180;
      final pivot = parent.endPosition;
      final dx = child.position.dx - pivot.dx;
      final dy = child.position.dy - pivot.dy;

      child.position = Offset(
        pivot.dx + dx * cos(rad) - dy * sin(rad),
        pivot.dy + dx * sin(rad) + dy * cos(rad),
      );
      child.rotation += angleDelta;

      _propagateRotation(childId, angleDelta);
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'bones': bones.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory Skeleton.fromJson(Map<String, dynamic> json) {
    final skeleton = Skeleton(name: json['name']);
    final bonesJson = json['bones'] as Map<String, dynamic>;
    for (final entry in bonesJson.entries) {
      skeleton.bones[entry.key] = Bone.fromJson(entry.value);
    }
    return skeleton;
  }

  Future<void> saveToFile(String path) async {
    final file = File(path);
    await file.writeAsString(jsonEncode(toJson()));
  }

  static Future<Skeleton> loadFromFile(String path) async {
    final file = File(path);
    final json = jsonDecode(await file.readAsString());
    return Skeleton.fromJson(json);
  }
}

/// Bone Editor Widget
class BoneEditor extends StatefulWidget {
  final String? backgroundImage;
  final Function(Skeleton)? onSkeletonChanged;
  final Skeleton? initialSkeleton;

  const BoneEditor({
    super.key,
    this.backgroundImage,
    this.onSkeletonChanged,
    this.initialSkeleton,
  });

  @override
  State<BoneEditor> createState() => BoneEditorState();
}

class BoneEditorState extends State<BoneEditor> {
  late Skeleton skeleton;
  String? selectedBoneId;
  String? hoveredBoneId;
  bool isDrawingBone = false;
  Offset? drawStart;
  String? drawParentId;

  // Edit modes
  bool drawMode = true;
  bool rotateMode = false;

  @override
  void initState() {
    super.initState();
    skeleton = widget.initialSkeleton ?? Skeleton(name: 'character');
  }

  void _startDrawing(Offset pos) {
    // Check if clicking on existing bone end
    for (final bone in skeleton.bones.values) {
      if ((bone.endPosition - pos).distance < 15) {
        drawParentId = bone.id;
        drawStart = bone.endPosition;
        isDrawingBone = true;
        setState(() {});
        return;
      }
    }

    // New root bone
    drawStart = pos;
    drawParentId = null;
    isDrawingBone = true;
    setState(() {});
  }

  void _finishDrawing(Offset pos) {
    if (!isDrawingBone || drawStart == null) return;

    final dx = pos.dx - drawStart!.dx;
    final dy = pos.dy - drawStart!.dy;
    final length = sqrt(dx * dx + dy * dy);

    if (length < 10) {
      // Too short, cancel
      isDrawingBone = false;
      drawStart = null;
      setState(() {});
      return;
    }

    final rotation = atan2(dy, dx) * 180 / pi;
    final id = 'bone_${DateTime.now().millisecondsSinceEpoch}';

    final bone = Bone(
      id: id,
      name: 'Bone ${skeleton.bones.length + 1}',
      position: drawStart!,
      length: length,
      rotation: rotation,
      parentId: drawParentId,
      color: _getNextColor(),
    );

    skeleton.addBone(bone);
    selectedBoneId = id;
    isDrawingBone = false;
    drawStart = null;

    widget.onSkeletonChanged?.call(skeleton);
    setState(() {});
  }

  Color _getNextColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.yellow,
    ];
    return colors[skeleton.bones.length % colors.length];
  }

  void _selectBone(Offset pos) {
    for (final bone in skeleton.bones.values) {
      // Check if clicking on bone line
      final start = bone.position;
      final end = bone.endPosition;
      final dist = _pointToLineDistance(pos, start, end);

      if (dist < 10) {
        selectedBoneId = bone.id;
        setState(() {});
        return;
      }
    }
    selectedBoneId = null;
    setState(() {});
  }

  double _pointToLineDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return (point - lineStart).distance;

    final t = max(0, min(1,
      ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / (len * len)
    ));

    final proj = Offset(
      lineStart.dx + t * dx,
      lineStart.dy + t * dy,
    );

    return (point - proj).distance;
  }

  void _rotateBoneToward(Offset pos) {
    if (selectedBoneId == null) return;
    final bone = skeleton.bones[selectedBoneId];
    if (bone == null) return;

    final dx = pos.dx - bone.position.dx;
    final dy = pos.dy - bone.position.dy;
    final angle = atan2(dy, dx) * 180 / pi;

    skeleton.setBoneRotation(selectedBoneId!, angle);
    widget.onSkeletonChanged?.call(skeleton);
    setState(() {});
  }

  /// Public method to set bone rotation from Node.js
  void setBoneRotation(String boneName, double angle) {
    final bone = skeleton.bones.values.firstWhere(
      (b) => b.name == boneName || b.id == boneName,
      orElse: () => Bone(id: '', name: '', position: Offset.zero),
    );
    if (bone.id.isEmpty) return;

    skeleton.setBoneRotation(bone.id, angle);
    setState(() {});
  }

  /// Get all bone names for Node.js
  List<String> getBoneNames() {
    return skeleton.bones.values.map((b) => b.name).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          color: const Color(0xFF1a1a2e),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _toolButton('Draw', Icons.edit, drawMode, () {
                setState(() { drawMode = true; rotateMode = false; });
              }),
              _toolButton('Rotate', Icons.rotate_right, rotateMode, () {
                setState(() { drawMode = false; rotateMode = true; });
              }),
              const SizedBox(width: 20),
              if (selectedBoneId != null) ...[
                Text(
                  skeleton.bones[selectedBoneId]?.name ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    skeleton.removeBone(selectedBoneId!);
                    selectedBoneId = null;
                    widget.onSkeletonChanged?.call(skeleton);
                    setState(() {});
                  },
                ),
              ],
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.save, color: Colors.green),
                label: const Text('Save', style: TextStyle(color: Colors.green)),
                onPressed: _saveSkeleton,
              ),
              TextButton.icon(
                icon: const Icon(Icons.folder_open, color: Colors.blue),
                label: const Text('Load', style: TextStyle(color: Colors.blue)),
                onPressed: _loadSkeleton,
              ),
            ],
          ),
        ),

        // Canvas
        Expanded(
          child: GestureDetector(
            onPanStart: (d) {
              if (drawMode) {
                _startDrawing(d.localPosition);
              } else {
                _selectBone(d.localPosition);
              }
            },
            onPanUpdate: (d) {
              if (drawMode && isDrawingBone) {
                setState(() {}); // Redraw preview
              } else if (rotateMode && selectedBoneId != null) {
                _rotateBoneToward(d.localPosition);
              }
            },
            onPanEnd: (d) {
              if (drawMode && isDrawingBone) {
                _finishDrawing(d.localPosition);
              }
            },
            onTapUp: (d) {
              if (!drawMode) {
                _selectBone(d.localPosition);
              }
            },
            child: CustomPaint(
              painter: BonePainter(
                skeleton: skeleton,
                selectedBoneId: selectedBoneId,
                hoveredBoneId: hoveredBoneId,
                isDrawing: isDrawingBone,
                drawStart: drawStart,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolButton(String label, IconData icon, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSkeleton() async {
    final path = 'C:\\wfl\\assets\\skeleton.json';
    await skeleton.saveToFile(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $path')),
      );
    }
  }

  Future<void> _loadSkeleton() async {
    try {
      final path = 'C:\\wfl\\assets\\skeleton.json';
      skeleton = await Skeleton.loadFromFile(path);
      selectedBoneId = null;
      widget.onSkeletonChanged?.call(skeleton);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
      }
    }
  }
}

/// Custom painter for bones
class BonePainter extends CustomPainter {
  final Skeleton skeleton;
  final String? selectedBoneId;
  final String? hoveredBoneId;
  final bool isDrawing;
  final Offset? drawStart;

  BonePainter({
    required this.skeleton,
    this.selectedBoneId,
    this.hoveredBoneId,
    this.isDrawing = false,
    this.drawStart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all bones
    for (final bone in skeleton.bones.values) {
      _drawBone(canvas, bone, bone.id == selectedBoneId);
    }

    // Draw preview line while drawing
    if (isDrawing && drawStart != null) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      // This would need current mouse position passed in
      // For now just show start point
      canvas.drawCircle(drawStart!, 8, paint);
    }
  }

  void _drawBone(Canvas canvas, Bone bone, bool selected) {
    final start = bone.position;
    final end = bone.endPosition;

    // Bone line
    final paint = Paint()
      ..color = selected ? Colors.yellow : bone.color
      ..strokeWidth = selected ? 4 : 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);

    // Joint circles
    final jointPaint = Paint()
      ..color = bone.color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(start, 6, jointPaint);
    canvas.drawCircle(end, 5, jointPaint);

    // Selection ring
    if (selected) {
      final ringPaint = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(start, 10, ringPaint);
    }

    // Bone name
    final textPainter = TextPainter(
      text: TextSpan(
        text: bone.name,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(
      (start.dx + end.dx) / 2 - textPainter.width / 2,
      (start.dy + end.dy) / 2 - textPainter.height - 5,
    ));
  }

  @override
  bool shouldRepaint(BonePainter oldDelegate) => true;
}
