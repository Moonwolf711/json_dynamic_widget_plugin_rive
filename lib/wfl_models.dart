import 'dart:typed_data';

/// Rive input names - enum prevents typos that freeze the mouth forever
/// (Legacy - kept for backwards compatibility with old .riv files)
enum RiveInput {
  isTalking('isTalking'),
  lipShape('lipShape'),
  windowAdded('windowAdded'),
  buttonState('buttonState'),
  btnTarget('btnTarget');

  final String name;
  const RiveInput(this.name);
}

/// Mouth cue for lip-sync timing
class MouthCue {
  final double time;
  final String mouth;

  MouthCue(this.time, this.mouth);
}

/// Button hit region for tap detection
class ButtonHitRegion {
  final double x;
  final double y;
  final double radius;
  final String name;

  const ButtonHitRegion(this.x, this.y, this.radius, this.name);
}

/// Queue item for back-to-back roasts
class QueueItem {
  final String id;
  final String path;
  final String filename;
  final int window;
  final Uint8List? thumbnail;

  QueueItem({
    required this.id,
    required this.path,
    required this.filename,
    required this.window,
    this.thumbnail,
  });
}

/// Export quality presets
class ExportPreset {
  final String name;
  final String resolution;
  final int fps;
  final int crf;
  final String description;

  const ExportPreset(
      this.name, this.resolution, this.fps, this.crf, this.description);

  static const youtube =
      ExportPreset('YouTube', '1080x720', 30, 18, '~120MB/min, crisp');
  static const stream =
      ExportPreset('Stream', '1080x720', 30, 24, '~80MB/min, fast');
  static const gif =
      ExportPreset('GIF Loop', '720x480', 30, 28, '~10MB, viral bait');
}

/// Character configuration for coordinate mapping and sprite features
class WFLCharacterConfig {
  static const Map<String, Map<String, dynamic>> characters = {
    'terry': {
      'mouthX': 95.0,
      'mouthY': 175.0,
      'mouthWidth': 110.0,
      'mouthHeight': 60.0,
      'eyesX': 70.0,
      'eyesY': 120.0,
      'eyesWidth': 160.0,
      'eyesHeight': 50.0,
      'hasEyes': false, // Terry's eyes are built into layers
    },
    'nigel': {
      'mouthX': 100.0,
      'mouthY': 185.0,
      'mouthWidth': 100.0,
      'mouthHeight': 55.0,
      'eyesX': 75.0,
      'eyesY': 130.0,
      'eyesWidth': 150.0,
      'eyesHeight': 45.0,
      'hasEyes': true, // Nigel has separate eye sprites
      'mouthFullFrame':
          true, // Nigel's mouth shapes are full-frame 2368x1792 PNGs (already positioned)
      'bodyAspectRatio': 1376.0 /
          752.0, // actual body image aspect ratio (1.83:1 = wider than tall)
    },
  };

  // Layer stacking order for each character (bottom to top)
  static const Map<String, List<String>> layerOrder = {
    'nigel': [
      'layer_05', // Back arm left
      'layer_06', // Back arm right
      'layer_04', // Torso/jacket
      'layer_02', // Head background
      'layer_03', // Face
      'layer_07', // Mid arms
      'layer_08',
      'layer_09', // Front arms
      'layer_10',
      'layer_11', // Hands
      'layer_12',
      'layer_13', // Legs
      'layer_14',
      'layer_15', // Robot arm
      'layer_01', // Hat on top
    ],
    'terry': [
      'layer_05', // Back elements
      'layer_06',
      'layer_04',
      'layer_02',
      'layer_03',
      'layer_07',
      'layer_08',
      'layer_09',
      'layer_10',
      'layer_11',
      'layer_12',
      'layer_13',
      'layer_14',
      'layer_15',
      'layer_16',
      'layer_17',
      'layer_18',
      'layer_19',
      'layer_20',
      'layer_01', // Top layer
    ],
  };
}
