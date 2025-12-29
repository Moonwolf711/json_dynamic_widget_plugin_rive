// WFL Controller - Rive 0.14.0 (rive_native) API
// State machine inputs: mouthState, headTurn, eyeState, roastTone, isTalking

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

class WFLController {
  rive.File? _file;
  rive.RiveWidgetController? _controller;
  rive.StateMachine? _sm;

  // Inputs from CockpitSM state machine
  rive.NumberInput? _mouthState;
  rive.NumberInput? _headTurn;
  rive.NumberInput? _eyeState;
  rive.NumberInput? _roastTone;
  rive.BooleanInput? _isTalking;

  bool get isReady => _controller != null && _sm != null;
  bool get hasInputs => _mouthState != null || _isTalking != null;
  rive.RiveWidgetController? get controller => _controller;

  Future<void> load([String assetPath = 'assets/wfl.riv']) async {
    await rive.RiveNative.init();

    _file = await rive.File.asset(assetPath, riveFactory: rive.Factory.rive);
    if (_file == null) {
      debugPrint('WFL: Failed to load $assetPath');
      return;
    }

    _controller = rive.RiveWidgetController(
      _file!,
      stateMachineSelector: rive.StateMachineSelector.byName('CockpitSM'),
    );

    // Wait for controller to initialize
    await Future.delayed(const Duration(milliseconds: 200));

    _sm = _controller!.stateMachine;
    debugPrint('WFL: State machine: ${_sm?.name}');

    // Bind inputs
    _mouthState = _sm?.number('mouthState') ?? _sm?.number('lipShape');
    _headTurn = _sm?.number('headTurn') ?? _sm?.number('terry_headTurn');
    _eyeState = _sm?.number('eyeState') ?? _sm?.number('pupilX');
    _roastTone = _sm?.number('roastTone') ?? _sm?.number('shipHue');
    _isTalking = _sm?.boolean('isTalking');

    debugPrint('WFL: Bound - mouth:${_mouthState != null} head:${_headTurn != null} eye:${_eyeState != null} tone:${_roastTone != null} talking:${_isTalking != null}');
  }

  // Controls
  void setMouth(double state) {
    if (_mouthState != null) _mouthState!.value = state;
  }
  void setHead(double deg) {
    if (_headTurn != null) _headTurn!.value = deg;
  }
  void setEye(double state) {
    if (_eyeState != null) _eyeState!.value = state;
  }
  void setTone(double tone) {
    if (_roastTone != null) _roastTone!.value = tone;
  }
  void talking(bool on) {
    if (_isTalking != null) _isTalking!.value = on;
  }

  // Legacy aliases for compatibility
  void setLip(double shape) => setMouth(shape);
  void terryHead(double deg) => setHead(deg);
  void nigelHead(double deg) => setHead(deg);
  void setPupils(double x, double y) => setEye(x);
  void setHue(double hue) => setTone(hue);

  // Lipsync helper
  Future<void> lipsync(String text, {int msPerChar = 80}) async {
    talking(true);
    for (final char in text.toLowerCase().split('')) {
      setMouth(_charToShape(char));
      await Future.delayed(Duration(milliseconds: msPerChar));
    }
    setMouth(0);
    talking(false);
  }

  double _charToShape(String char) {
    return switch (char) {
      'a' => 1, 'e' => 2, 'i' => 3, 'o' => 4, 'u' => 5,
      'f' || 'v' => 6, 'm' || 'b' || 'p' => 7, 'w' || 'l' || 'r' => 8,
      _ => 0,
    };
  }

  void dispose() {
    _controller?.dispose();
    _file?.dispose();
  }
}

class WFLWidget extends StatefulWidget {
  final String assetPath;
  final void Function(WFLController)? onReady;

  const WFLWidget({super.key, this.assetPath = 'assets/wfl.riv', this.onReady});

  @override
  State<WFLWidget> createState() => WFLWidgetState();
}

class WFLWidgetState extends State<WFLWidget> {
  final WFLController wfl = WFLController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    wfl.load(widget.assetPath).then((_) {
      setState(() => _ready = true);
      widget.onReady?.call(wfl);
    });
  }

  @override
  void dispose() {
    wfl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || wfl.controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return rive.RiveWidget(controller: wfl.controller!);
  }
}
