// voice_trigger.dart — Pure Dart voice trigger for Terry
// Uses platform audio APIs, sends commands to TCP server
// Zero packages — dart:io only

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Voice trigger controller — detects speech and controls Terry
class VoiceTrigger {
  final String host;
  final int port;
  final double silenceThreshold;
  final int speechMinMs;
  final int silenceMinMs;

  Socket? _socket;
  bool _connected = false;
  bool _listening = false;
  bool _isSpeaking = false;
  int _speechStart = 0;
  int _silenceStart = 0;

  // Callbacks
  void Function(bool speaking)? onSpeakingChanged;
  void Function(double amplitude)? onAmplitude;
  void Function(String event)? onEvent;

  // Viseme sequence for speech
  static const _speechVisemes = ['ah_open', 'ee_wide', 'oh', 'mp', 'neutral_closed'];

  VoiceTrigger({
    this.host = 'localhost',
    this.port = 3001,
    this.silenceThreshold = 0.02,
    this.speechMinMs = 100,
    this.silenceMinMs = 300,
  });

  /// Connect to Terry Live server
  Future<bool> connect() async {
    try {
      _socket = await Socket.connect(host, port);
      _connected = true;
      onEvent?.call('Connected to Terry');

      _socket!.listen(
        (data) {
          // Handle responses if needed
        },
        onDone: () {
          _connected = false;
          onEvent?.call('Disconnected');
        },
        onError: (e) {
          _connected = false;
          onEvent?.call('Connection error: $e');
        },
      );

      return true;
    } catch (e) {
      onEvent?.call('Connect failed: $e');
      return false;
    }
  }

  /// Disconnect
  void disconnect() {
    _socket?.close();
    _connected = false;
  }

  /// Send command to Terry
  void sendCommand(Map<String, dynamic> cmd) {
    if (_socket != null && _connected) {
      _socket!.write('${json.encode(cmd)}\n');
    }
  }

  // Convenience commands
  void setViseme(String viseme) => sendCommand({'type': 'set_viseme', 'viseme': viseme});
  void setEmotion(String emotion) => sendCommand({'type': 'set_emotion', 'emotion': emotion});
  void triggerBlink() => sendCommand({'type': 'trigger_blink'});
  void speak(List<String> phonemes, {int fps = 12}) =>
      sendCommand({'type': 'speak', 'phonemes': phonemes, 'fps': fps});

  /// Process audio amplitude (0.0 - 1.0)
  void processAmplitude(double amplitude) {
    onAmplitude?.call(amplitude);

    final now = DateTime.now().millisecondsSinceEpoch;
    final isSpeech = amplitude > silenceThreshold;

    if (isSpeech) {
      _silenceStart = 0;

      if (!_isSpeaking) {
        _speechStart = now;
        _isSpeaking = true;
        _onSpeechStart();
      }

      _onSpeechContinue(amplitude);
    } else {
      if (_isSpeaking) {
        if (_silenceStart == 0) {
          _silenceStart = now;
        } else if (now - _silenceStart > silenceMinMs) {
          final duration = now - _speechStart;
          _isSpeaking = false;
          _onSpeechEnd(duration);
        }
      }
    }
  }

  void _onSpeechStart() {
    onSpeakingChanged?.call(true);
    onEvent?.call('Speech started');

    setEmotion('curious');
    triggerBlink();
  }

  void _onSpeechContinue(double amplitude) {
    // Map amplitude to viseme
    final idx = (amplitude * (_speechVisemes.length - 1)).floor().clamp(0, _speechVisemes.length - 1);
    setViseme(_speechVisemes[idx]);
  }

  void _onSpeechEnd(int duration) {
    onSpeakingChanged?.call(false);
    onEvent?.call('Speech ended (${duration}ms)');

    setViseme('neutral_closed');

    if (duration > 2000) {
      setEmotion('happy');
      triggerBlink();

      // Terry responds
      Future.delayed(const Duration(milliseconds: 500), () {
        speak(['oh', 'ah_open', 'ee_wide', 'neutral_closed'], fps: 10);
      });
    } else if (duration > 500) {
      setEmotion('curious');
    } else {
      setEmotion('chill');
    }

    // Return to chill
    Future.delayed(const Duration(seconds: 3), () {
      setEmotion('chill');
    });
  }

  /// Hotword detected callback
  void onHotwordDetected() {
    onEvent?.call('>>> HEY TERRY! <<<');

    // Double blink
    triggerBlink();
    Future.delayed(const Duration(milliseconds: 200), triggerBlink);

    setEmotion('curious');
  }

  /// Simulate speech for testing
  void simulateSpeech({int durationMs = 1500}) {
    _onSpeechStart();

    int elapsed = 0;
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (elapsed >= durationMs) {
        timer.cancel();
        _onSpeechEnd(durationMs);
        return;
      }
      _onSpeechContinue(0.3 + Random().nextDouble() * 0.5);
      elapsed += 50;
    });
  }
}

/// Voice trigger widget with visual feedback
class VoiceTriggerWidget extends StatefulWidget {
  final VoiceTrigger trigger;
  final bool showWaveform;

  const VoiceTriggerWidget({
    super.key,
    required this.trigger,
    this.showWaveform = true,
  });

  @override
  State<VoiceTriggerWidget> createState() => _VoiceTriggerWidgetState();
}

class _VoiceTriggerWidgetState extends State<VoiceTriggerWidget> {
  bool _speaking = false;
  double _amplitude = 0;
  String _lastEvent = '';
  final List<double> _waveform = List.filled(30, 0);

  @override
  void initState() {
    super.initState();

    widget.trigger.onSpeakingChanged = (speaking) {
      setState(() => _speaking = speaking);
    };

    widget.trigger.onAmplitude = (amp) {
      setState(() {
        _amplitude = amp;
        _waveform.removeAt(0);
        _waveform.add(amp);
      });
    };

    widget.trigger.onEvent = (event) {
      setState(() => _lastEvent = event);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _speaking ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _speaking ? Colors.green : Colors.grey.shade600,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _speaking ? Icons.mic : Icons.mic_off,
                color: _speaking ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                _speaking ? 'Listening...' : 'Silent',
                style: TextStyle(
                  color: _speaking ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Waveform
          if (widget.showWaveform) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              width: 150,
              child: CustomPaint(
                painter: _WaveformPainter(_waveform, _speaking),
              ),
            ),
          ],

          // Event
          if (_lastEvent.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _lastEvent,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],

          // Test buttons
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.record_voice_over, size: 20),
                onPressed: () => widget.trigger.simulateSpeech(),
                tooltip: 'Simulate Speech',
                color: Colors.amber,
              ),
              IconButton(
                icon: const Icon(Icons.campaign, size: 20),
                onPressed: () => widget.trigger.onHotwordDetected(),
                tooltip: 'Hey Terry!',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Waveform painter
class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final bool active;

  _WaveformPainter(this.waveform, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? Colors.green : Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final barWidth = size.width / waveform.length;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final height = waveform[i] * size.height * 0.8;
      final y1 = size.height / 2 - height / 2;
      final y2 = size.height / 2 + height / 2;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}

/// Demo app with voice trigger
class VoiceTriggerDemoApp extends StatefulWidget {
  const VoiceTriggerDemoApp({super.key});

  @override
  State<VoiceTriggerDemoApp> createState() => _VoiceTriggerDemoAppState();
}

class _VoiceTriggerDemoAppState extends State<VoiceTriggerDemoApp> {
  late VoiceTrigger _trigger;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _trigger = VoiceTrigger();
    _connect();
  }

  Future<void> _connect() async {
    final success = await _trigger.connect();
    setState(() => _connected = success);
  }

  @override
  void dispose() {
    _trigger.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Voice Trigger Demo'),
          backgroundColor: Colors.black87,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _connected ? 'Connected to Terry' : 'Connecting...',
                style: TextStyle(
                  color: _connected ? Colors.green : Colors.orange,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              VoiceTriggerWidget(trigger: _trigger),
              const SizedBox(height: 24),
              const Text(
                'Press buttons to simulate\nvoice input to Terry',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
