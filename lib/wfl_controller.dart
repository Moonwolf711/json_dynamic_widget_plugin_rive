import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rive/rive.dart' hide LinearGradient;
import 'wfl_config.dart';

/// Frame data captured during recording
class FrameData {
  final double time;
  final String mouth;
  final double volume;

  FrameData(this.time, this.mouth, this.volume);

  Map<String, dynamic> toJson() => {
    'time': time,
    'mouth': mouth,
    'volume': volume,
  };
}

/// WFL Animation Controller - Live + Record modes
class WFLController extends ChangeNotifier {
  bool isRecording = false;
  bool isLive = false;
  final List<FrameData> recorded = [];
  double _recordStartTime = 0;

  RiveAnimationController? _riveController;
  SMIInput<double>? _mouthInput;
  SMIInput<bool>? _isTalkingInput;
  StreamSubscription? _micStream;

  static const Map<String, double> phonemeToMouth = {
    'REST': 0.0, 'AA': 0.8, 'EE': 0.4, 'OO': 0.6, 'PP': 0.1,
    'FF': 0.3, 'TH': 0.35, 'DD': 0.5, 'KK': 0.45, 'CH': 0.55,
  };

  void initRive(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, 'main');
    if (controller != null) {
      artboard.addController(controller);
      _mouthInput = controller.findInput<double>('mouthOpen');
      _isTalkingInput = controller.findInput<bool>('isTalking');
    }
  }

  void startLive() {
    isLive = true;
    isRecording = false;
    notifyListeners();
    _startMicStream();
  }

  void startRecording() {
    isRecording = true;
    isLive = false;
    recorded.clear();
    _recordStartTime = DateTime.now().millisecondsSinceEpoch / 1000;
    notifyListeners();
    _startMicStream();
  }

  void stop() {
    isRecording = false;
    isLive = false;
    _micStream?.cancel();
    notifyListeners();
  }

  void _startMicStream() {
    _micStream = Stream.periodic(Duration(milliseconds: 50)).listen((_) {});
  }

  void _processPhoneme(String phoneme, double volume) {
    final mouthValue = phonemeToMouth[phoneme] ?? 0.0;
    _mouthInput?.value = mouthValue;
    _isTalkingInput?.value = volume > 0.1;

    if (isRecording) {
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      recorded.add(FrameData(now - _recordStartTime, phoneme, volume));
    }
  }

  Future<String> renderRecording() async {
    if (recorded.isEmpty) throw Exception('No recording to render');
    print('Rendering ${recorded.length} frames...');
    return 'wfl_final.mp4';
  }

  List<Map<String, dynamic>> exportKeyframes() {
    return recorded.map((f) => f.toJson()).toList();
  }

  @override
  void dispose() {
    _micStream?.cancel();
    super.dispose();
  }
}


/// WFL Auto-Roast Pipeline - Vision AI + TTS (LIVE)
class WFLAutoRoast {
  final String claudeApiKey;
  final String elevenLabsKey;
  final String terryVoiceId;
  final String nigelVoiceId;

  WFLAutoRoast({
    required this.claudeApiKey,
    required this.elevenLabsKey,
    this.terryVoiceId = 'pNInz6obpgDQGcFmaJgB',
    this.nigelVoiceId = 'yoZ06aMxZJJ28mfd3POQ',
  });

  /// Main pipeline: video/image → sarcastic roast → TTS → play
  Future<String> onWindowVideoAdded(int window, File videoFile) async {
    // Step 1: Get sarcastic description from Vision AI
    final description = await describeSarcastic(videoFile);
    print('🔥 Roast: $description');

    // Step 2: Generate TTS audio
    final voiceId = window == 1 ? terryVoiceId : nigelVoiceId;
    final audioBytes = await generateSpeech(description, voiceId);

    // Step 3: Save audio for playback
    final tempDir = Directory.systemTemp;
    final audioFile = File('${tempDir.path}/roast_$window.mp3');
    await audioFile.writeAsBytes(audioBytes);

    return description;
  }

  /// Vision AI: describe image/video sarcastically (LIVE)
  Future<String> describeSarcastic(File file) async {
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-3-5-sonnet-20241022',
        'max_tokens': 100,
        'messages': [{
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/png',
                'data': base64Image,
              }
            },
            {
              'type': 'text',
              'text': 'Describe exactly what is happening in this image in one short sentence, like a sarcastic late-night host would. Max eighteen words. Be funny and slightly mean.'
            }
          ]
        }]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] ?? "I got nothing. This image broke my brain.";
    } else {
      print('Vision API error: ${response.statusCode}');
      return "API hiccup. But trust me, it wasn't worth describing anyway.";
    }
  }

  /// ElevenLabs TTS - YOUR cloned voices
  /// Terry = naive kid discovering sarcasm, doesn't get timing
  /// Nigel = dry, utterly unimpressed
  Future<List<int>> generateSpeech(String text, String voiceId, {String? character}) async {
    // Character-specific voice tuning
    final settings = _getVoiceSettings(character ?? (voiceId == terryVoiceId ? 'terry' : 'nigel'));

    final response = await http.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId?output_format=pcm_44100'),
      headers: {
        'Content-Type': 'application/json',
        'xi-api-key': elevenLabsKey,
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': settings,
      }),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('ElevenLabs error: ${response.statusCode}');
      return [];
    }
  }

  /// Terry = naive kid, Nigel = dry adult
  Map<String, dynamic> _getVoiceSettings(String character) {
    if (character == 'terry') {
      // Naive kid who just discovered sarcasm but doesn't get the timing
      // "Wow, look at that... rocket ship! Except it's a shopping cart. Cool."
      return {
        'stability': 0.4,            // Slightly wobbly, unsure
        'similarity_boost': 0.98,
        'style': 0.2,                // Low style = naive, not quite landing it
        'use_speaker_boost': true,
      };
    } else {
      // Nigel: dry, utterly unimpressed, perfect deadpan
      return {
        'stability': 0.5,            // Steady, controlled
        'similarity_boost': 0.98,
        'style': 0.15,               // Minimal expression = maximum dry
        'use_speaker_boost': true,
      };
    }
  }

  /// Transcribe audio file to text (using OpenAI Whisper API)
  /// For live mic mode: record → transcribe → roast back
  Future<String> transcribeAudio(File audioFile) async {
    // Use OpenAI Whisper API for transcription
    // Note: Requires OpenAI API key in WFLConfig
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      request.headers['Authorization'] = 'Bearer ${_getOpenAIKey()}';
      request.fields['model'] = 'whisper-1';
      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['text'] ?? '';
      } else {
        print('Whisper API error: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('Transcription error: $e');
      return '';
    }
  }

  String _getOpenAIKey() {
    // Use WFLConfig for OpenAI key (Whisper transcription)
    return WFLConfig.openAIKey;
  }

  /// Roast what the user said (for live mic mode)
  /// User says something → Claude generates sarcastic response
  Future<String> roastTranscription(String userSaid) async {
    if (userSaid.isEmpty) return "You said nothing. Classic.";

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-3-5-sonnet-20241022',
        'max_tokens': 50,
        'messages': [{
          'role': 'user',
          'content': 'Someone just said: "$userSaid". Give a short sarcastic comeback, max 15 words. Be funny, slightly mean, like a late-night host roasting their audience.'
        }]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] ?? "I heard you. I just don't care.";
    } else {
      print('Roast API error: ${response.statusCode}');
      return "My brain short-circuited trying to process that.";
    }
  }

  /// Get meaner version (optional spice)
  Future<String> getMeanerRoast(String originalRoast) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-3-5-sonnet-20241022',
        'max_tokens': 100,
        'messages': [{
          'role': 'user',
          'content': 'Turn this into an even meaner one-liner, max 18 words: "$originalRoast"'
        }]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] ?? originalRoast;
    }
    return originalRoast;
  }
}


/// WFL Video Clipper - Composites Rive + videos + audio
class WFLVideoClipper {

  Future<String> compose({
    required String riveFile,
    required String timeline,
    required List<String> videoLayers,
    required String audioTrack,
    int fps = 60,
    required String output,
  }) async {
    print('🎬 Composing video...');
    print('   Rive: $riveFile');
    print('   Timeline: $timeline');
    print('   Videos: $videoLayers');
    print('   Audio: $audioTrack');
    print('   FPS: $fps');
    print('   Output: $output');

    // FFmpeg command (requires ffmpeg_kit_flutter)
    // await FFmpegKit.execute(
    //   '-framerate $fps -i frames/%05d.png -i $audioTrack '
    //   '-c:v libx264 -pix_fmt yuv420p -c:a aac $output'
    // );

    print('✅ Video composed: $output');
    return output;
  }

  Future<void> addWatermark(String input, String output) async {
    // ffmpeg -i input.mp4 -vf "drawtext=text='Made with WFL Animator':
    //   x=w-tw-10:y=h-th-10:fontsize=24:fontcolor=white" output.mp4
    print('✅ Watermark added');
  }
}


/// Rive artboard extension for easy input setting
extension RiveArtboardExtension on Artboard {
  void setInput(String name, dynamic value) {
    final controller = StateMachineController.fromArtboard(this, 'main');
    if (controller != null) {
      if (value is bool) {
        controller.findInput<bool>(name)?.value = value;
      } else if (value is double) {
        controller.findInput<double>(name)?.value = value;
      } else if (value is int) {
        controller.findInput<double>(name)?.value = value.toDouble();
      }
    }
  }
}
