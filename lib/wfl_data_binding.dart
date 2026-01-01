import 'package:rive/rive.dart';

/// WFL Data Binding - Controller for Rive animations
///
/// Uses StateMachine inputs for controlling mouth shapes and character state.
/// Compatible with Rive 0.13+ API.

/// Mouth shape constants (maps to lipShape input values)
class MouthShape {
  static const double x = 0; // Closed
  static const double a = 1; // Wide open (ah)
  static const double e = 2; // Smile (eh)
  static const double i = 3; // Tight smile (ee)
  static const double o = 4; // Round (oh)
  static const double u = 5; // Pursed (oo)
  static const double f = 6; // Teeth visible (f/v)
  static const double l = 7; // Tongue (l/th)
  static const double m = 8; // Closed tight (m/b/p)

  /// Convert phoneme string to number
  static double fromPhoneme(String phoneme) {
    switch (phoneme.toLowerCase()) {
      case 'a': return a;
      case 'e': return e;
      case 'i': return i;
      case 'o': return o;
      case 'u': return u;
      case 'f': case 'v': return f;
      case 'l': case 'th': return l;
      case 'm': case 'b': case 'p': return m;
      default: return x;
    }
  }
}

/// Controller for a WFL character using StateMachine inputs
class WFLCharacterController {
  final String characterName;
  final Artboard artboard;

  StateMachineController? _stateMachine;
  SMINumber? _lipShape;
  SMIBool? _isTalking;
  SMINumber? _focusX;

  WFLCharacterController({
    required this.characterName,
    required this.artboard,
    String stateMachineName = 'cockpit',
  }) {
    _init(stateMachineName);
  }

  void _init(String stateMachineName) {
    // Get state machine controller
    _stateMachine = StateMachineController.fromArtboard(artboard, stateMachineName);

    if (_stateMachine != null) {
      artboard.addController(_stateMachine!);

      // Get inputs from state machine
      _lipShape = _stateMachine!.findInput<double>('lipShape') as SMINumber?;
      _isTalking = _stateMachine!.findInput<bool>('isTalking') as SMIBool?;
      _focusX = _stateMachine!.findInput<double>('focusX') as SMINumber?;

      print('✓ $characterName: StateMachine initialized');
      print('  lipShape: ${_lipShape != null}');
      print('  isTalking: ${_isTalking != null}');
      print('  focusX: ${_focusX != null}');
    } else {
      print('⚠ $characterName: No state machine "$stateMachineName" found');
    }
  }

  /// Set mouth shape (0-8 for different phonemes)
  void setMouth(double shape) {
    if (_lipShape != null) {
      _lipShape!.value = shape;
    }
  }

  /// Set mouth from phoneme string
  void setMouthFromPhoneme(String phoneme) {
    setMouth(MouthShape.fromPhoneme(phoneme));
  }

  /// Set talking state
  void setTalking(bool talking) {
    if (_isTalking != null) {
      _isTalking!.value = talking;
    }
  }

  /// Set eye focus (-1 = left, 0 = center, 1 = right)
  void setFocus(double x) {
    if (_focusX != null) {
      _focusX!.value = x;
    }
  }

  /// Check if state machine is available
  bool get hasDataBinding => _stateMachine != null && _lipShape != null;

  /// Get current lip shape value
  double get lipShape => _lipShape?.value ?? 0;

  /// Get current talking state
  bool get isTalking => _isTalking?.value ?? false;

  /// Get current focus
  double get focusX => _focusX?.value ?? 0;

  void dispose() {
    _stateMachine?.dispose();
  }
}

/// Manages multiple WFL characters
class WFLSceneController {
  final Map<String, WFLCharacterController> _characters = {};

  /// Add a character controller
  void addCharacter(String name, Artboard artboard, {String stateMachine = 'cockpit'}) {
    _characters[name] = WFLCharacterController(
      characterName: name,
      artboard: artboard,
      stateMachineName: stateMachine,
    );
  }

  /// Get character by name
  WFLCharacterController? operator [](String name) => _characters[name];

  /// Set mouth for a character
  void setMouth(String character, String phoneme) {
    _characters[character]?.setMouthFromPhoneme(phoneme);
  }

  /// Set talking state for a character
  void setTalking(String character, bool talking) {
    _characters[character]?.setTalking(talking);
  }

  /// Set all characters to closed mouth
  void resetAllMouths() {
    for (final c in _characters.values) {
      c.setMouth(MouthShape.x);
      c.setTalking(false);
    }
  }

  void dispose() {
    for (final c in _characters.values) {
      c.dispose();
    }
    _characters.clear();
  }
}
