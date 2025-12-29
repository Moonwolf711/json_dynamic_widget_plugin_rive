// Simple test to verify injected inputs
// Run with: flutter run -t lib/test_simple.dart

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('=== WFL Input Injection Test ===');
  debugPrint('');

  try {
    // Initialize Rive native runtime
    debugPrint('Initializing Rive...');
    await rive.RiveNative.init();
    debugPrint('Rive initialized OK');
  } catch (e) {
    debugPrint('Rive init error: $e');
    return;
  }

  // Test original file
  debugPrint('');
  debugPrint('--- Testing ORIGINAL wfl.riv ---');
  await _testFile('assets/wfl.riv');

  // Test modified file
  debugPrint('');
  debugPrint('--- Testing MODIFIED wfl_with_inputs.riv ---');
  await _testFile('assets/wfl_with_inputs.riv');

  debugPrint('');
  debugPrint('=== Test Complete ===');

  // Run minimal app
  runApp(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Check debug console for results',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

Future<void> _testFile(String path) async {
  try {
    debugPrint('Loading $path...');

    final file = await rive.File.asset(
      path,
      riveFactory: rive.Factory.rive,
    );

    if (file == null) {
      debugPrint('  ERROR: Failed to load file');
      return;
    }

    debugPrint('  File loaded OK');

    final controller = rive.RiveWidgetController(
      file,
      stateMachineSelector: rive.StateMachineSelector.byName('CockpitSM'),
    );

    debugPrint('  Controller created');

    // Give it time to initialize
    await Future.delayed(const Duration(milliseconds: 300));

    final sm = controller.stateMachine;
    debugPrint('  State machine: ${sm.name}');

    // Test each number input - get, set, verify
    final numberTests = {
      'mouthState': 5.0,
      'headTurn': -30.0,
      'eyeState': 2.0,
      'roastTone': 3.0,
    };

    for (final entry in numberTests.entries) {
      final name = entry.key;
      final testValue = entry.value;
      final input = sm.number(name);
      if (input != null) {
        final oldValue = input.value;
        input.value = testValue;
        final newValue = input.value;
        final success = (newValue == testValue) ? '✓' : '✗';
        debugPrint('  $name: $oldValue -> $testValue = $newValue $success');
      } else {
        debugPrint('  $name: NOT FOUND');
      }
    }

    // Test boolean input - get, set, verify
    final isTalking = sm.boolean('isTalking');
    if (isTalking != null) {
      final oldValue = isTalking.value;
      isTalking.value = true;
      final newValue = isTalking.value;
      final success = (newValue == true) ? '✓' : '✗';
      debugPrint('  isTalking: $oldValue -> true = $newValue $success');
    } else {
      debugPrint('  isTalking: NOT FOUND');
    }

    controller.dispose();
    file.dispose();
    debugPrint('  Cleanup OK');
  } catch (e, stack) {
    debugPrint('  ERROR: $e');
    debugPrint('  Stack: $stack');
  }
}
