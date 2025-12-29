// WFL Controller for Rive 0.14.0+
// Uses new C++ runtime with File caching

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// WFL Animation Controller - Rive 0.14.0 compatible
///
/// Usage:
/// ```dart
/// final wfl = WFLController();
/// await wfl.load();
///
/// // Control animations
/// wfl.setMouth(3.0);  // Lip shape 0-8
/// wfl.setHead(15.0);  // Head turn degrees
/// wfl.setTalking(true);
///
/// // In widget
/// if (wfl.isReady) {
///   RiveWidget(controller: wfl.controller!)
/// }
/// ```
class WFLController {
  File? _file;
  RiveWidgetController? _controller;

  // State machine inputs (will be null until .riv is fixed)
  SMINumber? _mouthState;
  SMINumber? _headTurn;
  SMINumber? _eyeState;
  SMINumber? _roastTone;
  SMIBool? _isTalking;

  bool get isReady => _controller != null;
  RiveWidgetController? get controller => _controller;

  /// Load the Rive file and create controller
  Future<void> load({
    String assetPath = 'assets/wfl.riv',
    String? artboardName,
    String stateMachineName = 'CockpitSM',
    bool useRiveRenderer = true,
  }) async {
    // Load file with specified renderer
    _file = await File.asset(
      assetPath,
      riveFactory: useRiveRenderer ? Factory.rive : Factory.flutter,
    );

    if (_file == null) {
      debugPrint('WFL: Failed to load $assetPath');
      return;
    }

    // Create controller with artboard and state machine selection
    _controller = RiveWidgetController(
      _file!,
      artboardSelector: artboardName != null
          ? ArtboardSelector.byName(artboardName)
          : const ArtboardSelector.byDefault(),
      stateMachineSelector: StateMachineSelector.byName(stateMachineName),
    );

    // Try to bind inputs
    _bindInputs();

    debugPrint('WFL: Loaded successfully. Inputs bound: ${_hasInputs ? 'YES' : 'NO'}');
  }

  void _bindInputs() {
    if (_controller == null) return;

    final sm = _controller!.stateMachine;

    // Try various input names
    _mouthState = sm.number('mouthState') ?? sm.number('lipShape');
    _headTurn = sm.number('headTurn') ?? sm.number('terry_headTurn');
    _eyeState = sm.number('eyeState') ?? sm.number('pupilX');
    _roastTone = sm.number('roastTone') ?? sm.number('shipHue');
    _isTalking = sm.boolean('isTalking');

    debugPrint('WFL: Inputs - mouth:${_mouthState != null} head:${_headTurn != null} '
               'eye:${_eyeState != null} tone:${_roastTone != null} talking:${_isTalking != null}');
  }

  bool get _hasInputs =>
      _mouthState != null || _headTurn != null || _isTalking != null;

  // === Control Methods ===

  /// Set mouth/lip shape (0-8 typically)
  void setMouth(double shape) => _mouthState?.value = shape;

  /// Set head turn angle in degrees
  void setHead(double degrees) => _headTurn?.value = degrees;

  /// Set eye state
  void setEye(double state) => _eyeState?.value = state;

  /// Set roast tone / hue
  void setTone(double tone) => _roastTone?.value = tone;

  /// Set talking state (enables blink loop, etc)
  void setTalking(bool talking) => _isTalking?.value = talking;

  // === Convenience Methods ===

  /// Simple lipsync from text
  Future<void> lipsync(String text, {int msPerChar = 80}) async {
    setTalking(true);
    for (final char in text.toLowerCase().split('')) {
      setMouth(_charToShape(char));
      await Future.delayed(Duration(milliseconds: msPerChar));
    }
    setMouth(0);
    setTalking(false);
  }

  double _charToShape(String char) {
    return switch (char) {
      'a' => 1, 'e' => 2, 'i' => 3, 'o' => 4, 'u' => 5,
      'f' || 'v' => 6, 'm' || 'b' || 'p' => 7, 'w' || 'l' || 'r' => 8,
      _ => 0,
    };
  }

  /// Dispose resources
  void dispose() {
    _controller?.dispose();
    _file?.dispose();
    _controller = null;
    _file = null;
  }
}

/// Stateful widget wrapper for WFLController
class WFLWidget extends StatefulWidget {
  final String assetPath;
  final String? artboardName;
  final String stateMachineName;
  final bool useRiveRenderer;
  final void Function(WFLController)? onReady;
  final Widget? placeholder;

  const WFLWidget({
    super.key,
    this.assetPath = 'assets/wfl.riv',
    this.artboardName,
    this.stateMachineName = 'CockpitSM',
    this.useRiveRenderer = true,
    this.onReady,
    this.placeholder,
  });

  @override
  State<WFLWidget> createState() => WFLWidgetState();
}

class WFLWidgetState extends State<WFLWidget> {
  final WFLController wfl = WFLController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await wfl.load(
        assetPath: widget.assetPath,
        artboardName: widget.artboardName,
        stateMachineName: widget.stateMachineName,
        useRiveRenderer: widget.useRiveRenderer,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onReady?.call(wfl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    wfl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? const Center(child: CircularProgressIndicator());
    }

    if (_error != null || !wfl.isReady) {
      return Center(
        child: Text(
          _error ?? 'Failed to load Rive',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return RiveWidget(
      controller: wfl.controller!,
      fit: Fit.contain,
    );
  }
}
