import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// Layer Manager - Upload and remove character layers
class WFLLayerManager extends StatefulWidget {
  final String terrySkeletonPath;
  final String nigelSkeletonPath;
  final String terryAssetsPath;
  final String nigelAssetsPath;
  final VoidCallback? onLayersChanged;

  const WFLLayerManager({
    super.key,
    required this.terrySkeletonPath,
    required this.nigelSkeletonPath,
    required this.terryAssetsPath,
    required this.nigelAssetsPath,
    this.onLayersChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String terrySkeletonPath,
    required String nigelSkeletonPath,
    required String terryAssetsPath,
    required String nigelAssetsPath,
    VoidCallback? onLayersChanged,
  }) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 800,
          height: 600,
          child: WFLLayerManager(
            terrySkeletonPath: terrySkeletonPath,
            nigelSkeletonPath: nigelSkeletonPath,
            terryAssetsPath: terryAssetsPath,
            nigelAssetsPath: nigelAssetsPath,
            onLayersChanged: onLayersChanged,
          ),
        ),
      ),
    );
  }

  @override
  State<WFLLayerManager> createState() => _WFLLayerManagerState();
}

class _WFLLayerManagerState extends State<WFLLayerManager> {
  Map<String, dynamic>? _terrySkeleton;
  Map<String, dynamic>? _nigelSkeleton;
  List<String> _terryLayers = [];
  List<String> _nigelLayers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSkeletons();
  }

  Future<void> _loadSkeletons() async {
    try {
      // Load Terry skeleton
      final terryFile = File(widget.terrySkeletonPath);
      if (await terryFile.exists()) {
        final terryJson = await terryFile.readAsString();
        _terrySkeleton = jsonDecode(terryJson);
        _terryLayers = _extractLayers(_terrySkeleton!);
      }

      // Load Nigel skeleton
      final nigelFile = File(widget.nigelSkeletonPath);
      if (await nigelFile.exists()) {
        final nigelJson = await nigelFile.readAsString();
        _nigelSkeleton = jsonDecode(nigelJson);
        _nigelLayers = _extractLayers(_nigelSkeleton!);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error loading skeletons: $e';
      });
    }
  }

  List<String> _extractLayers(Map<String, dynamic> skeleton) {
    final layers = <String>[];
    final bones = skeleton['bones'] as List<dynamic>? ?? [];
    for (final bone in bones) {
      final images = bone['images'] as List<dynamic>? ?? [];
      for (final img in images) {
        if (!layers.contains(img)) {
          layers.add(img as String);
        }
      }
    }
    return layers;
  }

  Future<void> _uploadLayer(String character) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        dialogTitle: 'Select layers for $character',
      );

      if (result == null || result.files.isEmpty) return;

      final assetsPath = character == 'terry'
          ? widget.terryAssetsPath
          : widget.nigelAssetsPath;
      final layersDir = Directory(path.join(assetsPath, 'layers'));

      // Create layers directory if it doesn't exist
      if (!await layersDir.exists()) {
        await layersDir.create(recursive: true);
      }

      for (final file in result.files) {
        if (file.path == null) continue;

        final sourceFile = File(file.path!);
        final fileName = path.basename(file.path!);
        final destPath = path.join(layersDir.path, fileName);

        // Copy file to assets
        await sourceFile.copy(destPath);

        // Add to skeleton
        final layerPath = 'layers/$fileName';
        if (character == 'terry') {
          _addLayerToSkeleton(_terrySkeleton!, layerPath);
          _terryLayers.add(layerPath);
        } else {
          _addLayerToSkeleton(_nigelSkeleton!, layerPath);
          _nigelLayers.add(layerPath);
        }
      }

      // Save updated skeleton
      await _saveSkeletons();
      setState(() {});
      widget.onLayersChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${result.files.length} layer(s) to $character')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addLayerToSkeleton(Map<String, dynamic> skeleton, String layerPath) {
    // Add to first bone that doesn't have this layer
    final bones = skeleton['bones'] as List<dynamic>;
    if (bones.isEmpty) return;

    // Find a body/torso bone or the first non-root bone
    Map<String, dynamic>? targetBone;
    for (final bone in bones) {
      final boneMap = bone as Map<String, dynamic>;
      final name = boneMap['name'] as String;
      if (name == 'body' || name == 'chest' || name == 'spine') {
        targetBone = boneMap;
        break;
      }
    }
    targetBone ??= bones.length > 1
        ? bones[1] as Map<String, dynamic>
        : bones[0] as Map<String, dynamic>;

    final images = (targetBone['images'] as List<dynamic>?) ?? [];
    if (!images.contains(layerPath)) {
      images.add(layerPath);
      targetBone['images'] = images;
    }
  }

  Future<void> _removeLayer(String character, String layerPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Layer?'),
        content: Text('Remove "$layerPath" from $character?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (character == 'terry') {
        _removeLayerFromSkeleton(_terrySkeleton!, layerPath);
        _terryLayers.remove(layerPath);
      } else {
        _removeLayerFromSkeleton(_nigelSkeleton!, layerPath);
        _nigelLayers.remove(layerPath);
      }

      // Optionally delete the file
      final assetsPath = character == 'terry'
          ? widget.terryAssetsPath
          : widget.nigelAssetsPath;
      final filePath = path.join(assetsPath, layerPath);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _saveSkeletons();
      setState(() {});
      widget.onLayersChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $layerPath from $character')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeLayerFromSkeleton(Map<String, dynamic> skeleton, String layerPath) {
    final bones = skeleton['bones'] as List<dynamic>;
    for (final bone in bones) {
      final images = bone['images'] as List<dynamic>?;
      if (images != null) {
        images.remove(layerPath);
      }
    }
  }

  Future<void> _saveSkeletons() async {
    const encoder = JsonEncoder.withIndent('  ');

    if (_terrySkeleton != null) {
      final terryFile = File(widget.terrySkeletonPath);
      await terryFile.writeAsString(encoder.convert(_terrySkeleton));
    }

    if (_nigelSkeleton != null) {
      final nigelFile = File(widget.nigelSkeletonPath);
      await nigelFile.writeAsString(encoder.convert(_nigelSkeleton));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layer Manager'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadSkeletons();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Row(
                  children: [
                    // Terry column
                    Expanded(
                      child: _buildCharacterColumn('Terry', 'terry', _terryLayers),
                    ),
                    const VerticalDivider(width: 1),
                    // Nigel column
                    Expanded(
                      child: _buildCharacterColumn('Nigel', 'nigel', _nigelLayers),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCharacterColumn(String name, String character, List<String> layers) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: character == 'terry' ? Colors.orange.shade100 : Colors.blue.shade100,
          child: Row(
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('${layers.length} layers', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),

        // Upload button
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            onPressed: () => _uploadLayer(character),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Layer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),

        const Divider(height: 1),

        // Layer list
        Expanded(
          child: layers.isEmpty
              ? const Center(
                  child: Text('No layers', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: layers.length,
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    return ListTile(
                      leading: const Icon(Icons.image, color: Colors.grey),
                      title: Text(
                        layer.split('/').last,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        layer,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeLayer(character, layer),
                        tooltip: 'Remove layer',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
