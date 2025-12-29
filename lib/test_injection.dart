// Quick test for WFL Cockpit state machine controller
// Run: flutter run -t lib/test_injection.dart

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'wfl_controller.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WFL Cockpit Test',
      theme: ThemeData.dark(),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final WFLController wfl = WFLController();
  String status = 'Loading...';
  double lipShape = 0;
  double terryHead = 0;
  double nigelHead = 0;
  double pupilX = 0;
  double pupilY = 0;
  double shipHue = 0;

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  Future<void> _loadRive() async {
    try {
      await wfl.load('assets/wfl.riv');
      setState(() {
        status = wfl.isReady
            ? (wfl.hasInputs ? 'Ready! Inputs bound.' : 'Loaded but NO INPUTS found')
            : 'Failed to load';
      });
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WFL Cockpit Test')),
      body: Column(
        children: [
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: wfl.hasInputs ? Colors.green : (wfl.isReady ? Colors.orange : Colors.red),
            child: Text(status, style: const TextStyle(fontSize: 18)),
          ),

          // Rive display
          Expanded(
            child: wfl.artboard != null
                ? Rive(artboard: wfl.artboard!)
                : const Center(child: CircularProgressIndicator()),
          ),

          // Controls
          if (wfl.isReady)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lip Shape
                    const Text('LIP SHAPE', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Shape: ${lipShape.toInt()}'),
                    Slider(
                      value: lipShape,
                      min: 0, max: 8, divisions: 8,
                      onChanged: (v) {
                        setState(() => lipShape = v);
                        wfl.setLip(v);
                      },
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => wfl.talking(true),
                          child: const Text('Talk ON'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => wfl.talking(false),
                          child: const Text('Talk OFF'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => wfl.lipsync('hello world'),
                          child: const Text('Lipsync'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Terry Head
                    const Text('TERRY HEAD TURN', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Degrees: ${terryHead.toInt()}'),
                    Slider(
                      value: terryHead,
                      min: -45, max: 45,
                      onChanged: (v) {
                        setState(() => terryHead = v);
                        wfl.terryHead(v);
                      },
                    ),

                    const SizedBox(height: 16),
                    // Nigel Head
                    const Text('NIGEL HEAD TURN', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Degrees: ${nigelHead.toInt()}'),
                    Slider(
                      value: nigelHead,
                      min: -45, max: 45,
                      onChanged: (v) {
                        setState(() => nigelHead = v);
                        wfl.nigelHead(v);
                      },
                    ),

                    const SizedBox(height: 16),
                    // Pupils
                    const Text('PUPILS', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('X: ${pupilX.toStringAsFixed(1)}, Y: ${pupilY.toStringAsFixed(1)}'),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('X'),
                              Slider(
                                value: pupilX,
                                min: -1, max: 1,
                                onChanged: (v) {
                                  setState(() => pupilX = v);
                                  wfl.setPupils(pupilX, pupilY);
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Y'),
                              Slider(
                                value: pupilY,
                                min: -1, max: 1,
                                onChanged: (v) {
                                  setState(() => pupilY = v);
                                  wfl.setPupils(pupilX, pupilY);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Ship Hue
                    const Text('SHIP HUE', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Hue: ${shipHue.toInt()}'),
                    Slider(
                      value: shipHue,
                      min: -180, max: 180,
                      onChanged: (v) {
                        setState(() => shipHue = v);
                        wfl.setHue(v);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
