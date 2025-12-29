// Test script to verify injected inputs in wfl_with_inputs.riv
// Run with: flutter run -t lib/test_injected_inputs.dart

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Rive native runtime (required for 0.14.0+)
  await rive.RiveNative.init();

  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WFL Input Test',
      theme: ThemeData.dark(),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String _originalStatus = 'Loading...';
  String _modifiedStatus = 'Loading...';

  rive.File? _modifiedFile;
  rive.RiveWidgetController? _modifiedController;

  // Track if inputs are available
  bool _hasMouthState = false;
  bool _hasHeadTurn = false;
  bool _hasEyeState = false;
  bool _hasRoastTone = false;
  bool _hasIsTalking = false;

  @override
  void initState() {
    super.initState();
    _testBothFiles();
  }

  Future<void> _testBothFiles() async {
    // Test original file
    await _testOriginal();

    // Test modified file
    await _testModified();
  }

  Future<void> _testOriginal() async {
    try {
      final file = await rive.File.asset(
        'assets/wfl.riv',
        riveFactory: rive.Factory.rive,
      );

      if (file == null) {
        setState(() {
          _originalStatus = 'ORIGINAL ERROR: Failed to load file';
        });
        return;
      }

      final controller = rive.RiveWidgetController(
        file,
        stateMachineSelector: rive.StateMachineSelector.byName('CockpitSM'),
      );

      // Wait for state machine to be ready
      await Future.delayed(const Duration(milliseconds: 200));

      final sm = controller.stateMachine;
      final inputs = <String>[];

      // Try to get inputs using 0.14.0 API
      try {
        if (sm.number('mouthState') != null) inputs.add('mouthState');
      } catch (_) {}
      try {
        if (sm.number('headTurn') != null) inputs.add('headTurn');
      } catch (_) {}
      try {
        if (sm.number('eyeState') != null) inputs.add('eyeState');
      } catch (_) {}
      try {
        if (sm.number('roastTone') != null) inputs.add('roastTone');
      } catch (_) {}
      try {
        if (sm.boolean('isTalking') != null) inputs.add('isTalking');
      } catch (_) {}

      setState(() {
        _originalStatus = 'ORIGINAL (wfl.riv):\n'
            '  State Machine: CockpitSM\n'
            '  Inputs found: ${inputs.isEmpty ? "NONE (0 inputs)" : inputs.join(", ")}';
      });

      controller.dispose();
      file.dispose();
    } catch (e) {
      setState(() {
        _originalStatus = 'ORIGINAL ERROR: $e';
      });
    }
  }

  Future<void> _testModified() async {
    try {
      _modifiedFile = await rive.File.asset(
        'assets/wfl_with_inputs.riv',
        riveFactory: rive.Factory.rive,
      );

      if (_modifiedFile == null) {
        setState(() {
          _modifiedStatus = 'MODIFIED ERROR: Failed to load file';
        });
        return;
      }

      _modifiedController = rive.RiveWidgetController(
        _modifiedFile!,
        stateMachineSelector: rive.StateMachineSelector.byName('CockpitSM'),
      );

      // Wait for state machine to be ready
      await Future.delayed(const Duration(milliseconds: 200));

      final sm = _modifiedController!.stateMachine;
      final inputs = <String>[];

      // Try to get inputs using 0.14.0 API
      try {
        _hasMouthState = sm.number('mouthState') != null;
        if (_hasMouthState) inputs.add('mouthState');
      } catch (_) {}
      try {
        _hasHeadTurn = sm.number('headTurn') != null;
        if (_hasHeadTurn) inputs.add('headTurn');
      } catch (_) {}
      try {
        _hasEyeState = sm.number('eyeState') != null;
        if (_hasEyeState) inputs.add('eyeState');
      } catch (_) {}
      try {
        _hasRoastTone = sm.number('roastTone') != null;
        if (_hasRoastTone) inputs.add('roastTone');
      } catch (_) {}
      try {
        _hasIsTalking = sm.boolean('isTalking') != null;
        if (_hasIsTalking) inputs.add('isTalking');
      } catch (_) {}

      setState(() {
        _modifiedStatus = 'MODIFIED (wfl_with_inputs.riv):\n'
            '  State Machine: CockpitSM\n'
            '  Inputs found: ${inputs.isEmpty ? "NONE" : inputs.join(", ")}\n\n'
            '  mouthState: ${_hasMouthState ? "OK" : "MISSING"}\n'
            '  headTurn: ${_hasHeadTurn ? "OK" : "MISSING"}\n'
            '  eyeState: ${_hasEyeState ? "OK" : "MISSING"}\n'
            '  roastTone: ${_hasRoastTone ? "OK" : "MISSING"}\n'
            '  isTalking: ${_hasIsTalking ? "OK" : "MISSING"}';
      });
    } catch (e) {
      setState(() {
        _modifiedStatus = 'MODIFIED ERROR: $e';
      });
    }
  }

  void _testControls() {
    if (_modifiedController == null) return;

    final sm = _modifiedController!.stateMachine;

    try {
      sm.number('mouthState')?.value = 3.0;
      debugPrint('Set mouthState to 3.0');
    } catch (e) {
      debugPrint('mouthState error: $e');
    }

    try {
      sm.number('headTurn')?.value = 15.0;
      debugPrint('Set headTurn to 15.0');
    } catch (e) {
      debugPrint('headTurn error: $e');
    }

    try {
      sm.boolean('isTalking')?.value = true;
      debugPrint('Set isTalking to true');
    } catch (e) {
      debugPrint('isTalking error: $e');
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WFL Input Injection Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original file status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _originalStatus,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),

            const SizedBox(height: 16),

            // Modified file status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _modifiedStatus,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),

            const SizedBox(height: 24),

            // Test controls button
            ElevatedButton(
              onPressed: _testControls,
              child: const Text('Test Controls (set values)'),
            ),

            const SizedBox(height: 24),

            // Rive widget preview
            if (_modifiedController != null)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: rive.RiveWidget(
                      controller: _modifiedController!,
                      fit: rive.Fit.contain,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _modifiedController?.dispose();
    _modifiedFile?.dispose();
    super.dispose();
  }
}
