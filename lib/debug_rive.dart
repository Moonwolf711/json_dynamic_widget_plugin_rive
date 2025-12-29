// Debug script to enumerate all state machines and inputs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

void main() {
  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Rive Debug')),
        body: const DebugScreen(),
      ),
    );
  }
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String output = 'Loading...';

  @override
  void initState() {
    super.initState();
    _debug();
  }

  Future<void> _debug() async {
    final buffer = StringBuffer();

    try {
      await RiveFile.initialize();
      final bytes = await rootBundle.load('assets/wfl.riv');
      final file = RiveFile.import(bytes);

      buffer.writeln('=== RIVE FILE DEBUG ===\n');
      buffer.writeln('Main artboard: ${file.mainArtboard.name}');

      final artboard = file.mainArtboard.instance();

      // Try all possible state machine names
      final smNames = [
        'cockpit', 'main', 'Main', 'CockpitSM', 'Cockpit', 'State Machine 1',
      ];

      buffer.writeln('\n=== STATE MACHINES ===\n');

      for (final name in smNames) {
        final controller = StateMachineController.fromArtboard(artboard, name);
        if (controller != null) {
          buffer.writeln('✓ Found: $name');
          buffer.writeln('  Inputs (${controller.inputs.length}):');
          for (final input in controller.inputs) {
            buffer.writeln('    - ${input.name} (${input.runtimeType})');
          }
          buffer.writeln('');
        }
      }

      buffer.writeln('\nDone scanning state machines.');

    } catch (e, stack) {
      buffer.writeln('Error: $e\n$stack');
    }

    final result = buffer.toString();
    debugPrint(result);
    setState(() => output = result);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        output,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
