// Test different ways to access Rive components
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Rive Access Test')),
        body: const TestScreen(),
      ),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String output = 'Loading...';
  Artboard? _artboard;
  StateMachineController? _controller;

  @override
  void initState() {
    super.initState();
    _testRive();
  }

  Future<void> _testRive() async {
    final buffer = StringBuffer();

    try {
      await RiveFile.initialize();
      final bytes = await rootBundle.load('assets/wfl.riv');
      final file = RiveFile.import(bytes);

      buffer.writeln('=== RIVE ACCESS TEST ===\n');
      buffer.writeln('Main artboard: ${file.mainArtboard.name}');

      _artboard = file.mainArtboard.instance();

      // Try to find state machine
      final smNames = ['CockpitSM', 'cockpit', 'Cockpit', 'main', 'State Machine 1'];

      for (final name in smNames) {
        _controller = StateMachineController.fromArtboard(_artboard!, name);
        if (_controller != null) {
          buffer.writeln('\nFound state machine: $name');
          buffer.writeln('Inputs: ${_controller!.inputs.length}');

          for (final input in _controller!.inputs) {
            buffer.writeln('  - ${input.name} (${input.runtimeType})');
          }

          _artboard!.addController(_controller!);
          break;
        }
      }

      if (_controller == null) {
        buffer.writeln('\nNo state machine found by name.');
      }

      // Try to find inputs directly using findInput on controller
      buffer.writeln('\n=== TRYING DIRECT INPUT LOOKUP ===\n');

      if (_controller != null) {
        final inputNames = ['mouthState', 'headTurn', 'eyeState', 'roastTone', 'isTalking',
                           'lipShape', 'buttonState', 'btnTarget', 'windowAdded'];

        for (final inputName in inputNames) {
          // Try as number
          final numInput = _controller!.findInput<double>(inputName);
          if (numInput != null) {
            buffer.writeln('FOUND (number): $inputName');
            continue;
          }

          // Try as bool
          final boolInput = _controller!.findInput<bool>(inputName);
          if (boolInput != null) {
            buffer.writeln('FOUND (bool): $inputName');
            continue;
          }

          buffer.writeln('NOT FOUND: $inputName');
        }
      }

      // Try accessing artboard components directly
      buffer.writeln('\n=== ARTBOARD COMPONENT ACCESS ===\n');

      // In Rive, you can access named objects via fill, stroke, etc.
      // Let's see what methods are available
      buffer.writeln('Artboard type: ${_artboard.runtimeType}');

      buffer.writeln('\n=== DONE ===');

    } catch (e, stack) {
      buffer.writeln('Error: $e');
      buffer.writeln(stack.toString().split('\n').take(10).join('\n'));
    }

    final result = buffer.toString();
    debugPrint(result);
    setState(() => output = result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_artboard != null)
          SizedBox(
            height: 300,
            child: Rive(artboard: _artboard!),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
