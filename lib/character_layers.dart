/// Character Layer System for WFL Viewer
/// Defines the body part hierarchy, rendering order, and customization options
/// for Terry (Australian Alien) and future characters.

/// Supported character views for different camera angles
enum CharacterView {
  front,
  threeQuarter,
  side,
  back,
}

/// Individual body part layer with customization properties
class CharacterLayer {
  final String id;
  final String name;
  final String description;
  final int renderOrder; // Lower = rendered first (back), Higher = rendered on top
  final List<String> includedParts; // Sub-components included in this layer
  final String? parentJoint; // Connection point to parent layer
  final String? childJoint; // Connection point for child layers
  final bool canCustomize; // Whether this part can be swapped/customized
  final String assetPath; // Relative path to the asset

  const CharacterLayer({
    required this.id,
    required this.name,
    required this.description,
    required this.renderOrder,
    this.includedParts = const [],
    this.parentJoint,
    this.childJoint,
    this.canCustomize = true,
    required this.assetPath,
  });
}

/// Color palette for character parts
class CharacterColors {
  final String id;
  final String name;
  final Map<String, String> colors; // Part ID -> Hex color

  const CharacterColors({
    required this.id,
    required this.name,
    required this.colors,
  });
}

/// Terry's default color palette
class TerryColors {
  static const String skin = '#7ED321'; // Bright green alien skin
  static const String bandana = '#1A1A1A'; // Black bandana base
  static const String bandanaPattern = '#FFFFFF'; // White paisley pattern
  static const String sunglasses = '#1A1A1A'; // Black frames
  static const String sunglassesLens = '#2D2D2D'; // Dark gray lenses
  static const String dreads = '#1A1A1A'; // Black dreads
  static const String shirt = '#E8E4D4'; // Cream/off-white shirt
  static const String shirtPattern = '#9E9E9E'; // Gray swirl pattern
  static const String shirtButtons = '#8B6914'; // Brown buttons
  static const String pants = '#2D2D2D'; // Dark gray pants
  static const String pantsHighlight = '#3D3D3D'; // Lighter gray for folds
  static const String boots = '#8B6914'; // Brown leather boots
  static const String bootsSole = '#4A3608'; // Darker brown sole
  static const String necklace = '#D4AF37'; // Gold chain
}

/// Complete character layer configuration
class CharacterLayerConfig {
  final String characterId;
  final String characterName;
  final CharacterView view;
  final List<CharacterLayer> layers;
  final CharacterColors colors;

  const CharacterLayerConfig({
    required this.characterId,
    required this.characterName,
    required this.view,
    required this.layers,
    required this.colors,
  });
}

/// Terry's layer definitions (Front View)
/// Render order: 0 = furthest back, 10 = frontmost
class TerryLayers {
  static const List<CharacterLayer> frontView = [
    // === BACK LAYERS (rendered first) ===
    CharacterLayer(
      id: 'left_leg_lower',
      name: 'Left Lower Leg',
      description: 'Left shin, calf, and cowboy boot',
      renderOrder: 0,
      includedParts: ['left_shin', 'left_calf', 'left_boot'],
      parentJoint: 'left_knee',
      assetPath: 'assets/characters/terry/layers/front/left_leg_lower.png',
    ),
    CharacterLayer(
      id: 'left_leg_upper',
      name: 'Left Upper Leg',
      description: 'Left thigh with dark gray pants',
      renderOrder: 1,
      includedParts: ['left_thigh'],
      parentJoint: 'left_hip',
      childJoint: 'left_knee',
      assetPath: 'assets/characters/terry/layers/front/left_leg_upper.png',
    ),
    CharacterLayer(
      id: 'right_leg_lower',
      name: 'Right Lower Leg',
      description: 'Right shin, calf, and cowboy boot',
      renderOrder: 2,
      includedParts: ['right_shin', 'right_calf', 'right_boot'],
      parentJoint: 'right_knee',
      assetPath: 'assets/characters/terry/layers/front/right_leg_lower.png',
    ),
    CharacterLayer(
      id: 'right_leg_upper',
      name: 'Right Upper Leg',
      description: 'Right thigh with dark gray pants',
      renderOrder: 3,
      includedParts: ['right_thigh'],
      parentJoint: 'right_hip',
      childJoint: 'right_knee',
      assetPath: 'assets/characters/terry/layers/front/right_leg_upper.png',
    ),

    // === TORSO (middle layer) ===
    CharacterLayer(
      id: 'torso',
      name: 'Torso',
      description: 'Cream patterned button-up shirt with gray swirls',
      renderOrder: 4,
      includedParts: ['chest', 'abdomen', 'shirt', 'buttons'],
      parentJoint: 'spine_base',
      childJoint: 'neck',
      assetPath: 'assets/characters/terry/layers/front/torso.png',
    ),

    // === ARMS (layered around torso) ===
    CharacterLayer(
      id: 'left_arm_lower',
      name: 'Left Lower Arm',
      description: 'Left forearm with shirt sleeve and green hand',
      renderOrder: 5,
      includedParts: ['left_forearm', 'left_hand', 'left_sleeve_lower'],
      parentJoint: 'left_elbow',
      assetPath: 'assets/characters/terry/layers/front/left_arm_lower.png',
    ),
    CharacterLayer(
      id: 'left_arm_upper',
      name: 'Left Upper Arm',
      description: 'Left upper arm with shirt sleeve',
      renderOrder: 6,
      includedParts: ['left_bicep', 'left_sleeve_upper'],
      parentJoint: 'left_shoulder',
      childJoint: 'left_elbow',
      assetPath: 'assets/characters/terry/layers/front/left_arm_upper.png',
    ),
    CharacterLayer(
      id: 'right_arm_lower',
      name: 'Right Lower Arm',
      description: 'Right forearm with shirt sleeve and green hand',
      renderOrder: 7,
      includedParts: ['right_forearm', 'right_hand', 'right_sleeve_lower'],
      parentJoint: 'right_elbow',
      assetPath: 'assets/characters/terry/layers/front/right_arm_lower.png',
    ),
    CharacterLayer(
      id: 'right_arm_upper',
      name: 'Right Upper Arm',
      description: 'Right upper arm with shirt sleeve',
      renderOrder: 8,
      includedParts: ['right_bicep', 'right_sleeve_upper'],
      parentJoint: 'right_shoulder',
      childJoint: 'right_elbow',
      assetPath: 'assets/characters/terry/layers/front/right_arm_upper.png',
    ),

    // === FRONT LAYERS (rendered last) ===
    CharacterLayer(
      id: 'necklace',
      name: 'Necklace',
      description: 'Gold rope chain necklace',
      renderOrder: 9,
      includedParts: ['chain'],
      parentJoint: 'neck',
      canCustomize: true, // Can be hidden or swapped
      assetPath: 'assets/characters/terry/layers/front/necklace.png',
    ),
    CharacterLayer(
      id: 'head',
      name: 'Head',
      description: 'Green alien head with bandana, sunglasses, and dreads',
      renderOrder: 10,
      includedParts: ['face', 'bandana', 'sunglasses', 'dreads'],
      parentJoint: 'neck',
      assetPath: 'assets/characters/terry/layers/front/head.png',
    ),
  ];

  /// Get all layers sorted by render order (back to front)
  static List<CharacterLayer> getSortedLayers(CharacterView view) {
    switch (view) {
      case CharacterView.front:
        return List.from(frontView)
          ..sort((a, b) => a.renderOrder.compareTo(b.renderOrder));
      default:
        return frontView; // TODO: Add other views
    }
  }

  /// Get a specific layer by ID
  static CharacterLayer? getLayerById(String id, {CharacterView view = CharacterView.front}) {
    final layers = getSortedLayers(view);
    try {
      return layers.firstWhere((layer) => layer.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Character variant definitions for customization options
class CharacterVariant {
  final String id;
  final String name;
  final Map<String, String> layerOverrides; // Layer ID -> alternate asset path
  final Map<String, bool> layerVisibility; // Layer ID -> visible

  const CharacterVariant({
    required this.id,
    required this.name,
    this.layerOverrides = const {},
    this.layerVisibility = const {},
  });
}

/// Terry's available variants
class TerryVariants {
  static const CharacterVariant standard = CharacterVariant(
    id: 'standard',
    name: 'Standard Terry',
  );

  static const CharacterVariant noNecklace = CharacterVariant(
    id: 'no_necklace',
    name: 'Terry (No Chain)',
    layerVisibility: {'necklace': false},
  );

  static const CharacterVariant casual = CharacterVariant(
    id: 'casual',
    name: 'Casual Terry',
    layerOverrides: {
      'torso': 'assets/characters/terry/layers/front/torso_casual.png',
    },
  );

  static const List<CharacterVariant> all = [
    standard,
    noNecklace,
    casual,
  ];
}

/// Part compatibility matrix - defines which parts work together
/// Used for validation when mixing and matching custom parts
class PartCompatibility {
  /// Check if two parts are compatible
  static bool areCompatible(String partA, String partB) {
    // All standard Terry parts are compatible with each other
    return true;
  }

  /// Matrix showing part availability across variants
  /// Row = Part, Column = Variant
  /// Values: true = available, false = not available
  static const Map<String, Map<String, bool>> matrix = {
    'head': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'necklace': {
      'standard': true,
      'no_necklace': false, // Hidden in this variant
      'casual': true,
    },
    'right_arm_upper': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'right_arm_lower': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'left_arm_upper': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'left_arm_lower': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'torso': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'right_leg_upper': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'right_leg_lower': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'left_leg_upper': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
    'left_leg_lower': {
      'standard': true,
      'no_necklace': true,
      'casual': true,
    },
  };
}

/// Joint connection points for skeletal animation
class JointDefinition {
  final String id;
  final String name;
  final double x; // Normalized X position (0-1)
  final double y; // Normalized Y position (0-1)
  final double rotationMin; // Minimum rotation in degrees
  final double rotationMax; // Maximum rotation in degrees

  const JointDefinition({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.rotationMin = -45,
    this.rotationMax = 45,
  });
}

/// Terry's skeletal joint definitions
class TerryJoints {
  static const List<JointDefinition> joints = [
    // Spine
    JointDefinition(id: 'spine_base', name: 'Spine Base', x: 0.5, y: 0.55),
    JointDefinition(id: 'neck', name: 'Neck', x: 0.5, y: 0.25, rotationMin: -30, rotationMax: 30),

    // Left Arm
    JointDefinition(id: 'left_shoulder', name: 'Left Shoulder', x: 0.25, y: 0.30, rotationMin: -90, rotationMax: 90),
    JointDefinition(id: 'left_elbow', name: 'Left Elbow', x: 0.10, y: 0.35, rotationMin: -135, rotationMax: 0),

    // Right Arm
    JointDefinition(id: 'right_shoulder', name: 'Right Shoulder', x: 0.75, y: 0.30, rotationMin: -90, rotationMax: 90),
    JointDefinition(id: 'right_elbow', name: 'Right Elbow', x: 0.90, y: 0.35, rotationMin: 0, rotationMax: 135),

    // Left Leg
    JointDefinition(id: 'left_hip', name: 'Left Hip', x: 0.40, y: 0.55, rotationMin: -45, rotationMax: 45),
    JointDefinition(id: 'left_knee', name: 'Left Knee', x: 0.35, y: 0.75, rotationMin: 0, rotationMax: 135),

    // Right Leg
    JointDefinition(id: 'right_hip', name: 'Right Hip', x: 0.60, y: 0.55, rotationMin: -45, rotationMax: 45),
    JointDefinition(id: 'right_knee', name: 'Right Knee', x: 0.65, y: 0.75, rotationMin: 0, rotationMax: 135),
  ];

  static JointDefinition? getJoint(String id) {
    try {
      return joints.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }
}
