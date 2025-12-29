import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class WflRiveWidget extends StatefulWidget {
  const WflRiveWidget({super.key});

  @override
  State<WflRiveWidget> createState() => _WflRiveWidgetState();
}

class _WflRiveWidgetState extends State<WflRiveWidget> {
  Artboard? _artboard;
  StateMachineController? _smController;

  // Public inputs – call these from your controller
  SMINumber? get lipShape =>
      _smController?.findInput<double>('lipShape') as SMINumber?;
  SMINumber? get terryHead =>
      _smController?.findInput<double>('terry_headTurn') as SMINumber?;
  SMINumber? get nigelHead =>
      _smController?.findInput<double>('nigel_headTurn') as SMINumber?;
  SMINumber? get pupilX =>
      _smController?.findInput<double>('pupilX') as SMINumber?;
  SMINumber? get pupilY =>
      _smController?.findInput<double>('pupilY') as SMINumber?;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  Future<void> _loadRiveFile() async {
    await RiveFile.initialize();
    final bytes = await rootBundle.load('assets/wfl.riv');
    final file = RiveFile.import(bytes); // ← new API
    final artboard = file.mainArtboard; // ← new API

    // Try multiple state machine names
    final names = ['Cockpit', 'cockpit', 'State Machine 1', 'Main', 'main'];
    StateMachineController? controller;
    String? foundName;

    for (final name in names) {
      controller = StateMachineController.fromArtboard(artboard, name);
      if (controller != null) {
        foundName = name;
        break;
      }
    }

    if (controller != null) {
      artboard.addController(controller);
      _smController = controller;
      // Log what we found
      final inputNames =
          controller.inputs.map((i) => '${i.name}(${i.runtimeType})').toList();
      debugPrint('=== RIVE LOADED ===');
      debugPrint('State machine: $foundName');
      debugPrint('Inputs found: $inputNames');
      debugPrint('==================');
    } else {
      debugPrint('ERROR: No state machine found. Tried: $names');
    }
    setState(() => _artboard = artboard);
  }

  @override
  Widget build(BuildContext context) {
    if (_artboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Rive(
      artboard: _artboard!,
      fit: BoxFit.cover,
    );
  }

  @override
  void dispose() {
    _smController?.dispose();
    super.dispose();
  }
}
