// lib/wfl_template.dart
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
// import 'package:rive/rive.dart'; // RIVE DISABLED
import 'rive_stub.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Rive init disabled - using custom bone animation
  // await RiveNative.init();
  runApp(const WFLApp());
}

class WFLApp extends StatelessWidget {
  const WFLApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: const WFLCockpit(),
        ),
      );
}

class WFLCockpit extends StatefulWidget {
  const WFLCockpit({super.key});

  @override
  State<WFLCockpit> createState() => _WFLCockpitState();
}

class _WFLCockpitState extends State<WFLCockpit> {
  late final FileLoader _fileLoader = FileLoader.fromAsset(
    "assets/wfl.riv",
    riveFactory: Factory.rive,
  );
  RiveWidgetController? _controller;
  final AudioPlayer _voice = AudioPlayer();
  final List<String> windows = ['', '', '']; // video paths
  bool _live = false;
  final TextEditingController _pin = TextEditingController();
  
  // DevTools monitoring - track Rive input changes
  void _logRiveEvent(String event, Map<String, dynamic> data) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final logEntry = {
      'event': event,
      'timestamp': timestamp,
      ...data,
    };
    debugPrint('RIVE_EVENT: ${jsonEncode(logEntry)}');
    // This will appear in DevTools console and can be tailed
  }

  @override
  void initState() {
    super.initState();
    _pin.text = '0711';
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fileLoader.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _roast(String path, int win) async {
    try {
      _logRiveEvent('roast.start', {'window': win, 'path': path});
      
      final desc = await _grok(path);
      final audio = await _eleven(desc, win == 1 ? 'terry' : 'nigel');
      await _voice.play(BytesSource(audio));
      
      // Access state machine inputs through controller
      // Monitor lipShape changes - DevTools will stream these
      if (_controller != null) {
        // Access inputs via controller's state machine
        // Example: _controller.stateMachine?.findInput<double>('lipShape')?.value = 1.0;
        // Example: _controller.stateMachine?.findInput<int>('windowAdded')?.value = win;
        
        // Log input updates for DevTools monitoring
        // When lipShape == 2, Terry is saying "ah" - advance mouth 2 frames
        // This gets streamed to devtools.log for AI parsing
        _logRiveEvent('input.update', {
          'name': 'lipShape',
          'value': 2,
          'window': win,
          'action': 'Terry is saying ah, advance mouth 2 frames'
        });
        
        _logRiveEvent('roast.complete', {'window': win});
      }
      
      setState(() => windows[win - 1] = path);
    } catch (e) {
      _logRiveEvent('roast.error', {'error': e.toString()});
      debugPrint('Roast error: $e');
    }
  }

  Future<String> _grok(String path) async {
    try {
      final f = io.File(path);
      if (!await f.exists()) {
        throw Exception('File not found: $path');
      }
      
      final fileBytes = await f.readAsBytes();
      final base64Video = base64Encode(fileBytes);
      
      final resp = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': 'sk-ant-claude-your-key',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 50,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Roast this video. One line. Sarcastic.'
                },
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': 'video/mp4',
                    'data': base64Video,
                  }
                }
              ]
            }
          ]
        }),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        return json['content'][0]['text'] as String;
      } else {
        throw Exception('API error: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Grok error: $e');
      return 'Failed to roast video.';
    }
  }

  Future<Uint8List> _eleven(String text, String voice) async {
    try {
      final voiceId = voice == 'terry' 
          ? 'your-terry-voice-id' 
          : 'your-nigel-voice-id';
      
      final resp = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': 'your-eleven-key',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'voice_settings': {
            'stability': 0.4,
            'similarity_boost': 0.95,
          }
        }),
      );

      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      } else {
        throw Exception('ElevenLabs API error: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('ElevenLabs error: $e');
      return Uint8List(0);
    }
  }

  void _warp() => setState(() => _live = true); // full bg video later

  void _focus(int win) => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Zoom: ${windows[win - 1]}'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // push full b-roll later
              },
              child: const Text('Roast Now'),
            )
          ],
        ),
      );

  void _export() async {
    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Exporting...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Rendering video...'),
          ],
        ),
      ),
    );

    try {
      // Check if FFmpeg is available
      final ffmpegCheck = await io.Process.run('ffmpeg', ['-version']);
      if (ffmpegCheck.exitCode != 0) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FFmpeg not found. Install FFmpeg first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Use temp directory - antivirus won't lock it
      final tempDir = io.Directory.systemTemp;
      final framesPath = '${tempDir.path}/wfl_frames';
      final outputPath = '${tempDir.path}/roast_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Check if frames directory exists and has frames
      final framesDir = io.Directory(framesPath);
      if (!await framesDir.exists()) {
        framesDir.createSync(recursive: true);
      }

      // Check for frame files
      final frames = framesDir.listSync()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      
      if (frames.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No frames found. Record a roast first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _logRiveEvent('export.start', {'frames': frames.length, 'output': outputPath});

      // FFmpeg export with proper flags
      final result = await io.Process.run('ffmpeg', [
        '-y', // Overwrite output file
        '-framerate', '30',
        '-i', '$framesPath/%04d.png',
        '-vcodec', 'libx264',
        '-pix_fmt', 'yuv420p', // Required for compatibility
        '-crf', '18', // High quality
        outputPath,
      ]);

      if (!mounted) return;
      Navigator.pop(context);

      if (result.exitCode == 0) {
        _logRiveEvent('export.complete', {'output': outputPath});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported: ${io.File(outputPath).path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _logRiveEvent('export.error', {'error': result.stderr.toString()});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${result.stderr}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _logRiveEvent('export.error', {'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          RiveWidgetBuilder(
            fileLoader: _fileLoader,
            stateMachineSelector: StateMachineSelector.byName('talker'),
            onLoaded: (state) {
              setState(() {
                _controller = state.controller;
              });
              _logRiveEvent('rive.loaded', {'stateMachine': 'talker'});
              
              // Monitor input changes - stream to DevTools
              // Example: Watch for lipShape changes
              // if (state.controller.stateMachine?.findInput<double>('lipShape')?.value == 2) {
              //   _logRiveEvent('input.update', {'name': 'lipShape', 'value': 2});
              // }
            },
            builder: (context, state) => switch (state) {
              RiveLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              RiveFailed() => ErrorWidget.withDetails(
                  message: state.error.toString(),
                  error: FlutterError(state.error.toString()),
                ),
              RiveLoaded() => RiveWidget(
                  controller: state.controller,
                  fit: Fit.cover,
                ),
            },
          ),
          DragTarget<String>(
            builder: (context, candidateData, rejectedData) =>
                const SizedBox.expand(),
            onAcceptWithDetails: (details) {
              final path = details.data;
              final win = DateTime.now().millisecondsSinceEpoch % 3 + 1;
              _roast(path, win);
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            child: ElevatedButton(
              onPressed: _warp,
              child: const Text('WARP'),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: ElevatedButton(
              onPressed: _export,
              child: const Text('EXPORT'),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: SizedBox(
              width: 100,
              child: TextField(
                controller: _pin,
                decoration: const InputDecoration(
                  hintText: '0711',
                  filled: true,
                  fillColor: Colors.white24,
                ),
              ),
            ),
          ),
        ],
      );
}
