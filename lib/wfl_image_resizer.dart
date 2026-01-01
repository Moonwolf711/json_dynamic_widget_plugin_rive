import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// WFL Image Resizer - Visual tool for resizing Dragonbone images to Illustrator specs
class WFLImageResizer extends StatefulWidget {
  const WFLImageResizer({super.key});

  @override
  State<WFLImageResizer> createState() => _WFLImageResizerState();
}

class _WFLImageResizerState extends State<WFLImageResizer> {
  // Artboard presets
  static const Map<String, Size> presets = {
    '1080p': Size(1920, 1080),
    '720p': Size(1280, 720),
    '4K': Size(3840, 2160),
    'Square': Size(1080, 1080),
    'Instagram': Size(1080, 1350),
  };

  // Current artboard size
  Size _artboardSize = const Size(1920, 1080);
  String _selectedPreset = '1080p';

  // Loaded image
  File? _imageFile;
  ui.Image? _image;
  String? _imageName;

  // Transform state
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isDragging = false;

  // Export key for RepaintBoundary
  final GlobalKey _exportKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0a12),
        title: const Text('Dragonbone Image Resizer'),
        actions: [
          // Preset dropdown
          DropdownButton<String>(
            value: _selectedPreset,
            dropdownColor: const Color(0xFF2a2a3e),
            style: const TextStyle(color: Colors.white),
            items: presets.keys.map((name) {
              final size = presets[name]!;
              return DropdownMenuItem(
                value: name,
                child: Text('$name (${size.width.toInt()}x${size.height.toInt()})'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPreset = value;
                  _artboardSize = presets[value]!;
                });
              }
            },
          ),
          const SizedBox(width: 16),

          // Export button
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Export Image',
            onPressed: _image != null ? _exportImage : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Side panel
          Container(
            width: 250,
            color: const Color(0xFF0a0a12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Load button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Load Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4a4a6e),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _loadImage,
                  ),
                ),
                const SizedBox(height: 24),

                // Image info
                if (_imageName != null) ...[
                  Text(
                    'Image:',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    _imageName!,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Original: ${_image!.width}x${_image!.height}',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],

                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),

                // Scale control
                Text('Scale: ${(_scale * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.white70)),
                Slider(
                  value: _scale,
                  min: 0.1,
                  max: 3.0,
                  divisions: 58,
                  onChanged: (v) => setState(() => _scale = v),
                ),

                const SizedBox(height: 16),

                // Position info
                Text(
                  'Position: (${_offset.dx.toStringAsFixed(0)}, ${_offset.dy.toStringAsFixed(0)})',
                  style: TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 24),

                // Reset button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Transform'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: _resetTransform,
                  ),
                ),

                const Spacer(),

                // Export info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a3e),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Size:',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        '${_artboardSize.width.toInt()} x ${_artboardSize.height.toInt()}',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Canvas area
          Expanded(
            child: Container(
              color: const Color(0xFF252538),
              child: Center(
                child: _buildCanvas(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    // Calculate display scale to fit canvas in view
    final viewSize = Size(
      MediaQuery.of(context).size.width - 250,
      MediaQuery.of(context).size.height - 56,
    );
    final displayScale = (viewSize.width * 0.8) / _artboardSize.width;
    final displayWidth = _artboardSize.width * displayScale;
    final displayHeight = _artboardSize.height * displayScale;

    return RepaintBoundary(
      key: _exportKey,
      child: GestureDetector(
        onPanStart: (_) => _isDragging = true,
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta / displayScale;
          });
        },
        onPanEnd: (_) => _isDragging = false,
        child: Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // Checkerboard background (transparency indicator)
                CustomPaint(
                  size: Size(displayWidth, displayHeight),
                  painter: CheckerboardPainter(),
                ),

                // Grid overlay
                CustomPaint(
                  size: Size(displayWidth, displayHeight),
                  painter: GridPainter(displayScale),
                ),

                // Image
                if (_image != null)
                  Positioned(
                    left: _offset.dx * displayScale,
                    top: _offset.dy * displayScale,
                    child: Transform.scale(
                      scale: _scale,
                      alignment: Alignment.topLeft,
                      child: RawImage(
                        image: _image,
                        fit: BoxFit.none,
                      ),
                    ),
                  ),

                // Center crosshair
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                    ),
                    child: CustomPaint(
                      painter: CrosshairPainter(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _imageFile = file;
        _image = frame.image;
        _imageName = result.files.first.name;
        _resetTransform();
      });
    }
  }

  void _resetTransform() {
    if (_image == null) {
      setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });
      return;
    }

    // Fit image to artboard
    final scaleX = _artboardSize.width / _image!.width;
    final scaleY = _artboardSize.height / _image!.height;
    final fitScale = scaleX < scaleY ? scaleX : scaleY;

    // Center image
    final scaledWidth = _image!.width * fitScale;
    final scaledHeight = _image!.height * fitScale;
    final offsetX = (_artboardSize.width - scaledWidth) / 2;
    final offsetY = (_artboardSize.height - scaledHeight) / 2;

    setState(() {
      _scale = fitScale;
      _offset = Offset(offsetX / fitScale, offsetY / fitScale);
    });
  }

  Future<void> _exportImage() async {
    if (_image == null) return;

    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw transparent background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _artboardSize.width, _artboardSize.height),
        Paint()..color = Colors.transparent,
      );

      // Draw the image with transforms
      canvas.save();
      canvas.translate(_offset.dx * _scale, _offset.dy * _scale);
      canvas.scale(_scale);
      canvas.drawImage(_image!, Offset.zero, Paint());
      canvas.restore();

      // Convert to image
      final picture = recorder.endRecording();
      final exportImage = await picture.toImage(
        _artboardSize.width.toInt(),
        _artboardSize.height.toInt(),
      );

      // Convert to PNG bytes
      final byteData = await exportImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      // Save file
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Resized Image',
        fileName: '${_imageName?.replaceAll('.', '_resized.')}'
            .replaceAll('_resized_resized', '_resized'),
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(byteData.buffer.asUint8List());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: $result'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Checkerboard painter for transparency
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 20.0;
    final paint1 = Paint()..color = const Color(0xFF404050);
    final paint2 = Paint()..color = const Color(0xFF303040);

    for (var y = 0.0; y < size.height; y += tileSize) {
      for (var x = 0.0; x < size.width; x += tileSize) {
        final isEven = ((x ~/ tileSize) + (y ~/ tileSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Grid painter
class GridPainter extends CustomPainter {
  final double displayScale;
  GridPainter(this.displayScale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    const gridSize = 100.0;
    final scaledGrid = gridSize * displayScale;

    for (var x = 0.0; x < size.width; x += scaledGrid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += scaledGrid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Crosshair painter
class CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
