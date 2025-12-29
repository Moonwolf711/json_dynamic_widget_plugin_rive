// WFL Rive Controller - Data Binding API (0.13+)
// Uses ViewModelInstance for property binding

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class TerryController {
  File? _file;
  RiveWidgetController? _controller;
  ViewModelInstance? _viewModel;

  // Data-bound properties
  ViewModelInstanceNumber? _lipShape;
  ViewModelInstanceNumber? _terryHeadTurn;
  ViewModelInstanceNumber? _nigelHeadTurn;
  ViewModelInstanceBoolean? _isTalking;

  bool get isReady => _controller != null && _viewModel != null;
  bool get hasInputs => _lipShape != null;
  RiveWidgetController? get controller => _controller;

  /// Load and init from asset path using data binding
  Future<void> load([String assetPath = 'assets/wfl.riv']) async {
    try {
      _file = await File.asset(assetPath);
      if (_file == null) {
        debugPrint('Rive: Failed to load file: $assetPath');
        return;
      }

      _controller = RiveWidgetController(_file!);
      _viewModel = _controller!.dataBind(DataBind.auto());

      _bindProperties();
    } catch (e) {
      debugPrint('Rive: Error loading file: $e');
    }
  }

  /// Bind properties from view model
  void _bindProperties() {
    if (_viewModel == null) return;

    // Try to find properties - names must match Rive editor exactly
    _lipShape = _viewModel!.number('lipShape');
    _terryHeadTurn = _viewModel!.number('terry_headTurn');
    _nigelHeadTurn = _viewModel!.number('nigel_headTurn');
    _isTalking = _viewModel!.boolean('isTalking');

    // Log what we found
    final found = <String>[];
    if (_lipShape != null) found.add('lipShape');
    if (_terryHeadTurn != null) found.add('terry_headTurn');
    if (_nigelHeadTurn != null) found.add('nigel_headTurn');
    if (_isTalking != null) found.add('isTalking');

    if (found.isEmpty) {
      debugPrint('Rive: No data-bound properties found');
      debugPrint('Rive: Check View Model in Rive Editor has exported properties');
    } else {
      debugPrint('Rive inputs found: ${found.join(', ')}');
    }
  }

  // ============ SETTERS ============

  void setLip(double shape) {
    _lipShape?.value = shape;
  }

  void turnHead(double deg) {
    _terryHeadTurn?.value = deg;
  }

  void turnNigelHead(double deg) {
    _nigelHeadTurn?.value = deg;
  }

  void talking(bool on) {
    _isTalking?.value = on;
  }

  // ============ LIPSYNC HELPER ============

  Future<void> lipsync(String text, {int msPerChar = 80}) async {
    talking(true);

    for (final char in text.toLowerCase().split('')) {
      setLip(_charToShape(char));
      await Future.delayed(Duration(milliseconds: msPerChar));
    }

    setLip(0);
    talking(false);
  }

  double _charToShape(String char) {
    return switch (char) {
      'a' => 1,
      'e' => 2,
      'i' => 3,
      'o' => 4,
      'u' => 5,
      'f' || 'v' => 6,
      'm' || 'b' || 'p' => 7,
      'w' || 'l' || 'r' => 8,
      _ => 0,
    };
  }

  void dispose() {
    _viewModel?.dispose();
    _controller?.dispose();
    _file?.dispose();
  }
}

// ============ WIDGET ============

class TerryWidget extends StatefulWidget {
  final String assetPath;
  final void Function(TerryController)? onReady;

  const TerryWidget({
    super.key,
    this.assetPath = 'assets/wfl.riv',
    this.onReady,
  });

  @override
  State<TerryWidget> createState() => TerryWidgetState();
}

class TerryWidgetState extends State<TerryWidget> {
  final TerryController terry = TerryController();

  @override
  void initState() {
    super.initState();
    terry.load(widget.assetPath).then((_) {
      setState(() {});
      widget.onReady?.call(terry);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!terry.isReady || terry.controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RiveWidget(controller: terry.controller!);
  }

  // Expose controls
  void setLip(double shape) => terry.setLip(shape);
  void turnHead(double deg) => terry.turnHead(deg);
  void turnNigelHead(double deg) => terry.turnNigelHead(deg);
  void talking(bool on) => terry.talking(on);
  Future<void> lipsync(String text) => terry.lipsync(text);

  @override
  void dispose() {
    terry.dispose();
    super.dispose();
  }
}
