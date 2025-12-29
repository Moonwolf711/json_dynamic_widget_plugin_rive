import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' show sin;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
// file_picker removed - using drag-and-drop instead
import 'package:rive/rive.dart' as rive hide LinearGradient, Image;
import 'package:path_provider/path_provider.dart';
// record package removed - live mic recording disabled for now
// import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'wfl_controller.dart';
import 'wfl_config.dart';
import 'wfl_uploader.dart';
import 'wfl_auto_roast.dart';
import 'wfl_focus_mode.dart';
import 'node_controller.dart';
import 'bone_editor.dart';
import 'wfl_menu_bar.dart';
import 'wfl_agent_chat.dart';

/// Rive input names - enum prevents typos that freeze the mouth forever
enum RiveInput {
  isTalking('isTalking'),
  lipShape('lipShape'),
  windowAdded('windowAdded'),
  buttonState('buttonState'),
  btnTarget('btnTarget');

  final String name;
  const RiveInput(this.name);
}

class WFLAnimator extends StatefulWidget {
  const WFLAnimator({super.key});

  @override
  State<WFLAnimator> createState() => _WFLAnimatorState();
}

class _WFLAnimatorState extends State<WFLAnimator>
    with TickerProviderStateMixin {
  /// Stream Rive events as JSON for DevTools/AI monitoring
  void _logRiveEvent(String event, [Map<String, dynamic>? data]) {
    final payload = {
      'event': event,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...?data,
    };
    debugPrint(jsonEncode(payload));
  }

  // Baked static images - loaded once, never again
  late final Image _spaceship;
  late final Image _terryBody;
  late final Image _nigelBody;
  late final Image _table;
  late final Image _buttonsPanel;

  // Rive animation state (0.14.0 API)
  rive.File? _riveFile;
  rive.RiveWidgetController? _riveController;
  rive.StateMachine? _riveStateMachine;
  rive.NumberInput? _lip;
  rive.NumberInput? _terryHead;
  rive.NumberInput? _nigelHead;
  rive.NumberInput? _terryEyes;
  rive.NumberInput? _terryRoast;
  rive.NumberInput? _pupilX;
  rive.NumberInput? _pupilY;
  rive.BooleanInput? _isTalkingRive; // Renamed to avoid conflict
  bool _riveLoaded = false;

  // Direct animation control (deprecated in Rive 0.14.0 - use state machine inputs)
  final Map<String, dynamic> _animations = {};
  List<String> _availableAnimations = [];
  bool _useDirectAnimation = false; // true when no state machine found

  // Audio player for voice lines
  final AudioPlayer _voicePlayer = AudioPlayer();

  // Three porthole video controllers
  VideoPlayerController? _porthole1;
  VideoPlayerController? _porthole2;
  VideoPlayerController? _porthole3;

  // Current mouth shape for lip-sync
  String _terryMouth = 'x';
  String _nigelMouth = 'x';

  // Nigel's eye state (eyes_open, eyes_closed, eyes_half, eyes_squint, eyes_wide)
  String _nigelEyes = 'eyes_open';

  // Lip-sync timer
  Timer? _lipSyncTimer;
  List<MouthCue> _currentCues = [];
  int _cueIndex = 0;
  DateTime? _audioStartTime;

  // Auto-roast pipeline
  late final WFLAutoRoast _autoRoast;

  // Rive inputs for cockpit buttons
  rive.NumberInput? _buttonState;
  rive.NumberInput? _btnTarget;
  rive.BooleanInput? _isTalking;

  // Keyboard focus
  final FocusNode _focusNode = FocusNode();

  // Button hit regions (x, y, radius, name)
  static const List<ButtonHitRegion> _buttonHitRegions = [
    ButtonHitRegion(100, 120, 30, 'thrusters'),
    ButtonHitRegion(200, 100, 30, 'warp'),
    ButtonHitRegion(300, 120, 30, 'shields'),
  ];

  // Button states: 0=off, 1=pulse, 2=on, 3=flash
  final Map<String, int> _buttonStates = {
    'thrusters': 0,
    'warp': 0,
    'shields': 0,
  };

  // React Mode: on = roast + lip-sync, off = just play clip clean
  bool _reactMode = true;

  // Preview queue for back-to-back roasts
  final List<QueueItem> _roastQueue = [];
  bool _isPlayingQueue = false;
  int _currentQueueIndex = 0;

  // Presets
  static const String _presetsKey = 'wfl_presets';

  // Volume: 0.0 (whisper) to 1.0 (TikTok loud)
  double _volume = 0.8;

  // Recording state
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final List<String> _capturedFrames = [];

  // Idle animation state
  double _idleTime = 0;
  Timer? _idleTimer;
  double _terryEyeX = 0, _terryEyeY = 0;
  double _nigelEyeX = 0, _nigelEyeY = 0;
  double _buttonGlow = 0.5;

  // Node.js WebSocket controller for remote control
  final NodeController _nodeController = NodeController();

  // BONE EDITOR MODE - draw bones directly in app
  bool _boneEditMode = false;
  final GlobalKey<BoneEditorState> _boneEditorKey =
      GlobalKey<BoneEditorState>();
  Skeleton? _skeleton;

  // WARP MODE - flying through video
  bool _isWarp = false;
  VideoPlayerController? _warpPlayer;
  double _warpSpeed = 0.87; // c units

  // FOCUS MODE - which window is focused for zoom roast
  int? _focusWindow;
  String? _lastRoastText;
  String? _lastRoastAudio;

  // Track if cockpit has keyboard focus (for hotkey hint)
  bool _hasFocus = true;

  // LIVE MIC MODE - disabled for now (record package removed)
  // final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isLiveMicOn = false; // Always false without record package
  bool _isRecordingMic = false;
  bool _hasMicPermission = false;

  // AGENT CHAT - AI-powered development assistant
  bool _chatExpanded = true;

  @override
  void initState() {
    super.initState();

    // Bake all static images ONCE - using YOUR actual assets
    _spaceship = Image.asset('assets/backgrounds/spaceship_iso.png');
    _terryBody = Image.asset('assets/characters/terry/layers/body.png');
    _nigelBody = Image.asset('assets/characters/nigel/layers/body.png');
    _table = Image.asset('assets/table.png');
    _buttonsPanel = Image.asset('assets/backgrounds/spaceship_buttons.png');

    // Initialize auto-roast from config
    _autoRoast = WFLAutoRoast(
      claudeApiKey: WFLConfig.claudeApiKey,
      elevenLabsKey: WFLConfig.elevenLabsKey,
      terryVoiceId: WFLConfig.terryVoiceId,
      nigelVoiceId: WFLConfig.nigelVoiceId,
    );

    // Listen for audio completion
    _voicePlayer.onPlayerComplete.listen((_) {
      _stopLipSync();
    });

    // Init uploader (check if YouTube already connected)
    WFLUploader.init();

    // Start idle animations - eyes wander, buttons breathe
    _startIdleAnimations();

    // Track focus changes for hotkey hint
    _focusNode.addListener(_onFocusChange);

    // Load Rive animation
    _loadRive();

    // Connect to Node.js control server
    _nodeController.onCommand = _handleNodeCommand;
    _nodeController.connect();
  }

  /// Handle commands from Node.js server
  void _handleNodeCommand(Map<String, dynamic> data) {
    final command = data['command'] as String?;
    debugPrint('NodeCommand: $command - $data');

    switch (command) {
      case 'rive':
        _handleRiveCommand(data);
        break;
      case 'roast':
        // Trigger roast with video/audio URL or local path
        final footage = data['footage'] as String? ?? data['video'] as String?;
        final target = data['target'] as String? ?? 'Unknown';
        final character = data['character'] as String? ?? 'terry';

        debugPrint('ROAST: $target via $footage (character: $character)');

        if (footage != null) {
          _startUrlRoast(footage, target, character);
        }
        break;
      case 'warp':
        _toggleWarpMode();
        break;
      case 'export':
        _exportVideo();
        break;
      case 'sync':
        // Sync state back to server
        _nodeController.sendStatus('ready', {
          'riveLoaded': _riveLoaded,
          'reactMode': _reactMode,
          'boneEditMode': _boneEditMode,
          'bones': _skeleton?.bones.keys.toList() ?? [],
        });
        break;
      case 'bone':
        // Control bones from Node.js
        final boneName = data['name'] as String?;
        final angle = (data['angle'] as num?)?.toDouble();
        if (boneName != null &&
            angle != null &&
            _boneEditorKey.currentState != null) {
          _boneEditorKey.currentState!.setBoneRotation(boneName, angle);
        }
        break;
      case 'bones':
        // Toggle bone edit mode
        setState(() => _boneEditMode = true);
        break;
      case 'setRiveUrl':
        // Set remote Rive URL from admin panel
        final url = data['url'] as String?;
        _remoteRiveUrl = url;
        debugPrint('Rive URL set to: ${url ?? 'local'}');
        break;
      case 'reloadRive':
        // Reload Rive file (local or remote)
        final url = data['url'] as String?;
        _remoteRiveUrl = url;
        debugPrint('Reloading Rive from: ${url ?? 'local'}');
        _loadRive();
        break;
      case 'playAnim':
        // Play animation by name (direct animation mode)
        final animName = data['name'] as String?;
        if (animName != null) {
          playAnimation(animName);
        }
        break;
      case 'stopAnim':
        // Stop animation by name
        final animName = data['name'] as String?;
        if (animName != null) {
          stopAnimation(animName);
        }
        break;
      case 'listAnims':
        // Return list of available animations
        _nodeController.send({
          'type': 'animations',
          'animations': _availableAnimations,
          'mode': _useDirectAnimation ? 'direct' : 'stateMachine',
        });
        break;
    }
  }

  /// Handle Rive-specific commands from Node.js
  void _handleRiveCommand(Map<String, dynamic> data) {
    final input = data['input'] as String?;
    final character = data['character'] as String? ?? 'terry';

    switch (input) {
      case 'lipShape':
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        _setRiveLip(value);
        // Also update PNG fallback
        setState(() {
          if (character == 'nigel') {
            _nigelMouth = _riveToMouth(value.toInt());
          } else {
            _terryMouth = _riveToMouth(value.toInt());
          }
        });
        break;
      case 'terry_headTurn':
      case 'terryHead':
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        // Convert from -40..40 to -1..1 if needed
        final normalized = value.abs() > 1 ? value / 40 : value;
        _setTerryHead(normalized);
        break;
      case 'nigel_headTurn':
      case 'nigelHead':
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        final normalized = value.abs() > 1 ? value / 40 : value;
        _setNigelHead(normalized);
        break;
      case 'terryEyes':
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        _setTerryEyes(value);
        break;
      case 'terryRoast':
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        _setTerryRoast(value);
        break;
      case 'pupil':
        final x = (data['x'] as num?)?.toDouble() ?? 0;
        final y = (data['y'] as num?)?.toDouble() ?? 0;
        _setPupils(x, y);
        break;
      case 'isTalking':
        final talking = data['value'] as bool? ?? false;
        _setTalking(talking);
        break;
      case 'nigelEyes':
        final eyeState = data['value'] as String? ?? 'open';
        setState(() => _nigelEyes = 'eyes_$eyeState');
        break;
    }
  }

  /// Convert Rive lip value to mouth shape string
  String _riveToMouth(int value) {
    switch (value) {
      case 1:
        return 'a';
      case 2:
        return 'e';
      case 3:
        return 'i';
      case 4:
        return 'o';
      case 5:
        return 'u';
      case 6:
        return 'f';
      case 7:
        return 'm';
      default:
        return 'x';
    }
  }

  // Remote Rive URL - set via /admin or env
  static String? _remoteRiveUrl;
  static set riveUrl(String? url) => _remoteRiveUrl = url;

  /// Load Rive file and bind inputs (Rive 0.14.0 API)
  Future<void> _loadRive() async {
    try {
      // Initialize Rive native runtime first
      await rive.RiveNative.init();

      // Load Rive file (using wfl_with_inputs.riv which has injected inputs)
      _riveFile = await rive.File.asset('assets/wfl_with_inputs.riv', riveFactory: rive.Factory.rive);
      if (_riveFile == null) {
        debugPrint('Rive: Failed to load assets/wfl_with_inputs.riv');
        setState(() => _riveLoaded = false);
        return;
      }

      // Create controller with CockpitSM state machine
      _riveController = rive.RiveWidgetController(
        _riveFile!,
        stateMachineSelector: rive.StateMachineSelector.byName('CockpitSM'),
      );

      // Wait for controller to initialize
      await Future.delayed(const Duration(milliseconds: 300));

      _riveStateMachine = _riveController!.stateMachine;
      debugPrint('Rive: State machine: ${_riveStateMachine?.name}');

      // Bind inputs using new API
      _lip = _riveStateMachine?.number('mouthState') ?? _riveStateMachine?.number('lipShape');
      _terryHead = _riveStateMachine?.number('headTurn') ?? _riveStateMachine?.number('terry_headTurn');
      _nigelHead = _riveStateMachine?.number('nigelHead') ?? _riveStateMachine?.number('nigel_headTurn');
      _terryEyes = _riveStateMachine?.number('eyeState') ?? _riveStateMachine?.number('terryEyes');
      _terryRoast = _riveStateMachine?.number('roastTone') ?? _riveStateMachine?.number('terryRoast');
      _pupilX = _riveStateMachine?.number('pupilX');
      _pupilY = _riveStateMachine?.number('pupilY');
      _isTalkingRive = _riveStateMachine?.boolean('isTalking');

      // Check if any inputs were found
      final hasInputs = _lip != null || _terryHead != null || _isTalkingRive != null;
      _useDirectAnimation = !hasInputs;

      debugPrint('Rive bound: lip=${_lip != null}, terryHead=${_terryHead != null}, '
          'nigelHead=${_nigelHead != null}, isTalking=${_isTalkingRive != null}');

      if (!hasInputs) {
        debugPrint('Rive: Inputs not bound - state machine inputs may be missing');
      }

      // Test: trigger animation by setting isTalking
      if (_isTalkingRive != null) {
        _isTalkingRive!.value = true;
        debugPrint('Rive: Set isTalking=true to trigger animation');
      }

      setState(() {
        _riveLoaded = true;
      });
      debugPrint('Rive: Widget should now be visible');
    } catch (e) {
      debugPrint('Rive load error: $e');
      setState(() => _riveLoaded = false);
    }
  }

  /// Setup direct animation controllers (legacy - not used with 0.14.0 API)
  /// Kept for backwards compatibility with files without state machines
  void _setupDirectAnimations() {
    // Direct animation control is deprecated in Rive 0.14.0
    // All animations should use state machine inputs
    debugPrint('Rive: Direct animation control not available in 0.14.0 API');
  }

  /// Play an animation by exact name
  void playAnimation(String name, {bool loop = false, double mix = 1.0}) {
    if (!_useDirectAnimation || !_animations.containsKey(name)) return;

    final anim = _animations[name];
    if (anim != null) {
      anim.isActive = true;
      debugPrint('Rive: Playing animation: $name');
    }
  }

  /// Stop an animation by name
  void stopAnimation(String name) {
    if (!_useDirectAnimation || !_animations.containsKey(name)) return;

    final anim = _animations[name];
    if (anim != null) {
      anim.isActive = false;
    }
  }

  /// Play first animation matching any of the patterns
  void _playAnimationMatching(List<String> patterns, {bool loop = false}) {
    for (final animName in _availableAnimations) {
      final lowerName = animName.toLowerCase();
      for (final pattern in patterns) {
        if (lowerName.contains(pattern)) {
          playAnimation(animName, loop: loop);
          return;
        }
      }
    }
  }

  /// Stop animations matching patterns
  void _stopAnimationMatching(List<String> patterns) {
    for (final animName in _availableAnimations) {
      final lowerName = animName.toLowerCase();
      for (final pattern in patterns) {
        if (lowerName.contains(pattern)) {
          stopAnimation(animName);
        }
      }
    }
  }

  /// Direct animation: Set mouth shape (0-8) by playing corresponding animation
  void _setMouthDirect(int shape) {
    if (!_useDirectAnimation) return;

    // Stop all mouth animations first
    _stopAnimationMatching(['mouth', 'lip']);

    // Find and play matching mouth animation
    // Try patterns: mouth_0, mouth_shape_0, lip_0, mouth_closed, mouth_open, etc.
    final patterns = [
      'mouth_$shape',
      'mouth_shape_$shape',
      'lip_$shape',
      'mouth${shape}',
    ];

    // Also try named shapes
    const shapeNames = ['closed', 'a', 'e', 'i', 'o', 'u', 'f', 'm', 'open'];
    if (shape < shapeNames.length) {
      patterns.add('mouth_${shapeNames[shape]}');
      patterns.add('${shapeNames[shape]}');
    }

    for (final animName in _availableAnimations) {
      final lowerName = animName.toLowerCase();
      for (final pattern in patterns) {
        if (lowerName.contains(pattern.toLowerCase())) {
          playAnimation(animName);
          return;
        }
      }
    }
  }

  /// Direct animation: Play head shake/turn
  void _playHeadAnimation(String type) {
    if (!_useDirectAnimation) return;

    _playAnimationMatching(['head_$type', '${type}_head', type]);
  }

  /// Drive Rive lip shape (0-7 for different mouth shapes)
  void _setRiveLip(double value) {
    if (_useDirectAnimation) {
      _setMouthDirect(value.toInt());
    } else {
      _lip?.value = value;
    }
  }

  /// Drive Terry's head turn (-1 to 1, negative = left)
  void _setTerryHead(double value) {
    if (_useDirectAnimation) {
      // Map -1 to 1 range to head turn animation
      if (value < -0.3) {
        _playAnimationMatching(['terry_head_left', 'head_left', 'turn_left']);
      } else if (value > 0.3) {
        _playAnimationMatching(
            ['terry_head_right', 'head_right', 'turn_right']);
      } else {
        _stopAnimationMatching(['head_left', 'head_right', 'turn']);
      }
    } else {
      _terryHead?.value = value.clamp(-1, 1);
    }
  }

  /// Drive Nigel's head turn (-1 to 1, negative = left)
  void _setNigelHead(double value) {
    if (_useDirectAnimation) {
      if (value < -0.3) {
        _playAnimationMatching(['nigel_head_left', 'head_left']);
      } else if (value > 0.3) {
        _playAnimationMatching(['nigel_head_right', 'head_right']);
      } else {
        // Play head shake if available
        _playAnimationMatching(['nigel_head_shake', 'head_shake']);
      }
    } else {
      _nigelHead?.value = value.clamp(-1, 1);
    }
  }

  /// Drive Terry's eyes (0=open, 1=closed, 2=half, 3=squint, 4=wide)
  void _setTerryEyes(double value) {
    if (_useDirectAnimation) {
      const eyeStates = ['open', 'closed', 'half', 'squint', 'wide'];
      final idx = value.clamp(0, 4).toInt();
      _stopAnimationMatching(['eye']);
      _playAnimationMatching(
          ['terry_eyes_${eyeStates[idx]}', 'eyes_${eyeStates[idx]}']);
    } else {
      _terryEyes?.value = value.clamp(0, 4);
    }
  }

  /// Drive Terry's roast attitude (0=chill, 1=smirk, 2=roast, etc)
  void _setTerryRoast(double value) {
    if (_useDirectAnimation) {
      const attitudes = ['chill', 'smirk', 'roast', 'angry'];
      final idx = value.clamp(0, 3).toInt();
      _playAnimationMatching(['terry_${attitudes[idx]}', attitudes[idx]]);
    } else {
      _terryRoast?.value = value;
    }
  }

  /// Drive pupil position
  void _setPupils(double x, double y) {
    if (_useDirectAnimation) {
      // Map X/Y to look direction animations
      if (x < -5) {
        _playAnimationMatching(['look_left', 'eyes_left']);
      } else if (x > 5) {
        _playAnimationMatching(['look_right', 'eyes_right']);
      }
      if (y < -3) {
        _playAnimationMatching(['look_down', 'eyes_down']);
      } else if (y > 3) {
        _playAnimationMatching(['look_up', 'eyes_up']);
      }
    } else {
      _pupilX?.value = x.clamp(-20, 20);
      _pupilY?.value = y.clamp(-10, 10);
    }
  }

  /// Set talking state (triggers blink loop in Rive)
  void _setTalking(bool talking) {
    if (_useDirectAnimation) {
      if (talking) {
        _playAnimationMatching(['talk', 'talking', 'speak', 'blink']);
      } else {
        _stopAnimationMatching(['talk', 'talking', 'speak']);
      }
    } else {
      _isTalkingRive?.value = talking;
    }
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _startIdleAnimations() {
    _idleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _idleTime += 0.05;
      setState(() {
        // Eyes wander (sine wave, different frequencies)
        _terryEyeX = sin(_idleTime * 0.7) * 3;
        _terryEyeY = sin(_idleTime * 0.5) * 2;
        _nigelEyeX = sin(_idleTime * 0.6 + 1) * 3;
        _nigelEyeY = sin(_idleTime * 0.4 + 0.5) * 2;

        // Buttons breathe (slow pulse)
        _buttonGlow = 0.5 + sin(_idleTime * 0.8) * 0.2;
      });
    });
  }

  /// Toggle recording - 30fps, 1080x720, max 60 seconds
  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _capturedFrames.clear();
    });

    // Timer for seconds display + auto-stop at 60s
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 60) {
        _stopRecording();
      }
    });

    // TODO: Actual frame capture would use RepaintBoundary + RenderRepaintBoundary.toImage()
    // For now, we'll export via FFmpeg from the live view
    debugPrint('Recording started - 30fps, 1080x720');
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);

    // Show export dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text('Recording Complete',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Captured $_recordingSeconds seconds.\nExport now?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportVideo();
            },
            child: const Text('Export'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportAndPost();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Export & Post'),
          ),
        ],
      ),
    );
  }

  /// Connect/disconnect YouTube
  Future<void> _toggleYouTube() async {
    if (WFLUploader.isYouTubeConnected) {
      // Show disconnect confirmation
      final disconnect = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a3e),
          title: const Text('Disconnect YouTube?',
              style: TextStyle(color: Colors.white)),
          content: const Text('You\'ll need to sign in again to upload.',
              style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Disconnect', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (disconnect == true) {
        await WFLUploader.disconnectYouTube();
        setState(() {});
      }
    } else {
      // Connect
      final connected = await WFLUploader.connectYouTube();
      if (!mounted) return;
      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube connected! Ready to post.')),
        );
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nodeController.disconnect();
    _voicePlayer.dispose();
    _porthole1?.dispose();
    _porthole2?.dispose();
    _porthole3?.dispose();
    _warpPlayer?.dispose();
    _lipSyncTimer?.cancel();
    _idleTimer?.cancel();
    _recordingTimer?.cancel();
    // _audioRecorder.dispose(); // record package removed
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  /// Request mic permission with dialog
  Future<bool> _requestMicPermission() async {
    // Check current status
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      _hasMicPermission = true;
      return true;
    }

    // Show explanation dialog first
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.orange),
            SizedBox(width: 8),
            Text('Mic Permission', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Live Mic Mode needs microphone access to hear what you say and roast it back.\n\n'
          'Your audio is sent to speech-to-text, then Claude roasts it.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Allow Mic'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    // Actually request permission
    status = await Permission.microphone.request();
    _hasMicPermission = status.isGranted;

    if (!_hasMicPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mic denied. Enable in system settings.')),
      );
    }

    return _hasMicPermission;
  }

  /// Toggle live mic mode
  Future<void> _toggleLiveMic() async {
    if (_isLiveMicOn) {
      // Turn off
      await _stopLiveMicRecording();
      setState(() => _isLiveMicOn = false);
      return;
    }

    // Request permission first
    if (!_hasMicPermission) {
      final granted = await _requestMicPermission();
      if (!granted) return;
    }

    setState(() => _isLiveMicOn = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live Mic ON - Hold MIC button to talk')),
    );
  }

  /// Start recording from mic (hold to talk)
  /// DISABLED - record package removed for Windows build
  Future<void> _startLiveMicRecording() async {
    // Live mic recording disabled - record package not available
    return;
  }

  /// Stop recording and process through roast pipeline
  /// DISABLED - record package removed for Windows build
  Future<void> _stopLiveMicRecording() async {
    // Live mic recording disabled - record package not available
    return;
  }

  /// Initialize additional Rive inputs (called after _loadRive)
  void _bindAdditionalInputs() {
    if (_riveStateMachine == null) return;

    // Bind button-specific inputs
    _buttonState = _riveStateMachine?.number(RiveInput.buttonState.name);
    _btnTarget = _riveStateMachine?.number(RiveInput.btnTarget.name);
    _isTalking = _riveStateMachine?.boolean(RiveInput.isTalking.name);

    _logRiveEvent('rive.loaded', {
      'stateMachine': _riveStateMachine?.name,
      'hasInputs': _lip != null || _isTalkingRive != null,
    });
  }

  /// Handle keyboard shortcuts: F1=thrusters, F2=warp, F3=shields, SHIFT+W=warp, SHIFT+F=focus, SHIFT+B=bones
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // SHIFT+B = toggle bone edit mode
    if (event.logicalKey == LogicalKeyboardKey.keyB && isShift) {
      setState(() => _boneEditMode = !_boneEditMode);
      debugPrint('Bone edit mode: $_boneEditMode');
      return;
    }

    // SHIFT+W = toggle warp mode
    if (event.logicalKey == LogicalKeyboardKey.keyW && isShift) {
      _toggleWarpMode();
      return;
    }

    // SHIFT+F = focus mode (zoom roast)
    if (event.logicalKey == LogicalKeyboardKey.keyF && isShift) {
      _enterFocusMode();
      return;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.f1:
        _pressButton('thrusters');
        break;
      case LogicalKeyboardKey.f2:
        _pressButton('warp');
        break;
      case LogicalKeyboardKey.f3:
        _pressButton('shields');
        break;
    }
  }

  /// Enter FOCUS MODE - zoom roast on the last active window
  Future<void> _enterFocusMode() async {
    // Find which window has video
    String? videoPath;
    int windowNum = 1;
    String character = 'terry';

    if (_porthole1 != null && _porthole1!.value.isInitialized) {
      videoPath = _porthole1!.dataSource;
      windowNum = 1;
      character = 'terry';
    } else if (_porthole2 != null && _porthole2!.value.isInitialized) {
      videoPath = _porthole2!.dataSource;
      windowNum = 2;
      character = 'nigel';
    } else if (_porthole3 != null && _porthole3!.value.isInitialized) {
      videoPath = _porthole3!.dataSource;
      windowNum = 3;
      character = 'terry';
    }

    if (videoPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drop a video first, then hit SHIFT+F')),
      );
      return;
    }

    // Set focus target (for head turn animation)
    _focusWindow = windowNum;
    setState(() {});

    // Wait for head turn
    await Future.delayed(const Duration(milliseconds: 600));

    // Navigate to focus mode
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenBroll(
            videoPath: videoPath!,
            roastText: _lastRoastText,
            roastAudio: _lastRoastAudio,
            character: character,
            onExport: () => _exportFocusModeClip(videoPath!),
          ),
        ),
      );
    }

    _focusWindow = null;
    setState(() {});
  }

  Future<void> _exportFocusModeClip(String videoPath) async {
    // Export the zoom roast as a clip
    debugPrint('Exporting Zoom Roast: $videoPath');
    // Would use FFmpeg to composite character overlay on video
  }

  /// Start URL-based roast - load audio from URL and lip sync
  String? _currentRoastTarget;

  Future<void> _startUrlRoast(
      String url, String target, String character) async {
    _currentRoastTarget = target;
    debugPrint('Starting URL roast: $target');

    // Show target name overlay
    setState(() {});

    try {
      // Play audio from URL
      if (url.startsWith('http')) {
        await _voicePlayer.play(UrlSource(url));
      } else {
        // Local file
        await _voicePlayer.play(DeviceFileSource(url));
      }

      // Start fake lip sync while audio plays
      _setTalking(true);
      if (character == 'nigel') {
        setState(() => _isTalking?.value = true);
      }

      // Animate mouth randomly while playing
      _lipSyncTimer?.cancel();
      _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
        if (_voicePlayer.state != PlayerState.playing) {
          timer.cancel();
          _setTalking(false);
          _setRiveLip(0);
          setState(() {
            if (character == 'nigel') {
              _nigelMouth = 'x';
            } else {
              _terryMouth = 'x';
            }
            _currentRoastTarget = null;
          });
          return;
        }

        // Random mouth flap
        final shape = (DateTime.now().millisecondsSinceEpoch ~/ 80) % 7 + 1;
        _setRiveLip(shape.toDouble());
        setState(() {
          final mouth = _riveToMouth(shape);
          if (character == 'nigel') {
            _nigelMouth = mouth;
          } else {
            _terryMouth = mouth;
          }
        });
      });

      // Notify server
      _nodeController.sendStatus('roasting', {
        'target': target,
        'character': character,
      });
    } catch (e) {
      debugPrint('URL roast error: $e');
      _currentRoastTarget = null;
      setState(() {});
    }
  }

  /// Toggle WARP MODE - flying through video
  Future<void> _toggleWarpMode() async {
    if (_isWarp) {
      // Exit warp
      _warpPlayer?.pause();
      setState(() => _isWarp = false);
    } else {
      // Enter warp - prompt for video path (no file_picker needed)
      final pathController = TextEditingController();
      final path = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a3e),
          title: const Text('WARP MODE', style: TextStyle(color: Colors.green)),
          content: TextField(
            controller: pathController,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'C:\\Videos\\clip.mp4',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, pathController.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('ENGAGE'),
            ),
          ],
        ),
      );

      if (path == null || path.isEmpty) return;

      final file = io.File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found')),
        );
        return;
      }

      _warpPlayer?.dispose();
      _warpPlayer = VideoPlayerController.file(file);
      await _warpPlayer!.initialize();
      _warpPlayer!.setLooping(true);
      _warpPlayer!.setVolume(0); // Silent - just visuals
      await _warpPlayer!.play();

      setState(() => _isWarp = true);
    }
  }

  /// Hit test cockpit tap → find button + re-focus keyboard
  void _onCockpitTap(TapDownDetails details) {
    // Always re-request focus on tap
    _focusNode.requestFocus();

    final x = details.localPosition.dx;
    final y = details.localPosition.dy;

    for (final region in _buttonHitRegions) {
      final dx = x - region.x;
      final dy = y - region.y;
      if (dx * dx + dy * dy <= region.radius * region.radius) {
        _pressButton(region.name);
        return;
      }
    }
  }

  /// Press button: flash → on, play character grunt
  Future<void> _pressButton(String btn) async {
    // Toggle state
    final currentState = _buttonStates[btn] ?? 0;
    final newState = currentState == 0 ? 2 : 0; // off ↔ on

    // Flash first
    _setButtonState(btn, 3); // flash
    await Future.delayed(const Duration(milliseconds: 300));
    _setButtonState(btn, newState); // on or off

    _buttonStates[btn] = newState;

    // Character reaction
    if (newState == 2) {
      await _playButtonReaction(btn);
    }
  }

  void _setButtonState(String btn, int state) {
    // Rive 0.13+/0.14+: avoid string inputs; use a numeric selector instead.
    _btnTarget?.value = _buttonTargetSelector(btn);
    _buttonState?.value = state.toDouble();
    setState(() {});
  }

  double _buttonTargetSelector(String btn) {
    switch (btn) {
      case 'thrusters':
        return 0;
      case 'warp':
        return 1;
      case 'shields':
        return 2;
      default:
        return 0;
    }
  }

  /// Play character audio for button press
  Future<void> _playButtonReaction(String btn) async {
    String audioFile;
    String character;

    switch (btn) {
      case 'thrusters':
        audioFile = 'assets/audio/terry_thrusters.mp3';
        character = 'terry';
        break;
      case 'warp':
        audioFile = 'assets/audio/terry_warp_on.mp3';
        character = 'terry';
        break;
      case 'shields':
        audioFile = 'assets/audio/nigel_shields.mp3';
        character = 'nigel';
        break;
      default:
        return;
    }

    // Set talking state
    _isTalking?.value = true;
    _playReaction(character, 'grunt');

    try {
      await _voicePlayer
          .play(AssetSource(audioFile.replaceFirst('assets/', '')));
    } catch (_) {
      // Audio file not found, just animate
    }

    // Reset after delay
    await Future.delayed(const Duration(milliseconds: 800));
    _isTalking?.value = false;
  }

  /// Drop a video/image into a porthole window - via path input
  Future<void> _onPortholeDropped(int window) async {
    final pathController = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: Text('Load into Window $window',
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: pathController,
          autofocus: false,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'C:\\Videos\\clip.mp4',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pathController.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (path == null || path.isEmpty) return;

    final file = io.File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }

    final ext = path.split('.').last.toLowerCase();

    // Video or image?
    if (['mp4', 'mov', 'avi', 'webm'].contains(ext)) {
      await _loadPortholeVideo(window, file);
    }

    // Trigger character reaction + auto-roast
    await _onWindowContentAdded(window, file);
  }

  Future<void> _loadPortholeVideo(int window, io.File file) async {
    final controller = VideoPlayerController.file(file);

    try {
      await controller.initialize();

      // Check if video is actually playing - H.264 baseline issues on Windows
      controller.setLooping(true);
      await controller.play();

      // Give it a moment to start
      await Future.delayed(const Duration(milliseconds: 200));

      // Fallback: if not playing, format is likely incompatible
      if (!controller.value.isPlaying && controller.value.hasError) {
        controller.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video skipped — convert to MP4 (H.264) first'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        switch (window) {
          case 1:
            _porthole1?.dispose();
            _porthole1 = controller;
            break;
          case 2:
            _porthole2?.dispose();
            _porthole2 = controller;
            break;
          case 3:
            _porthole3?.dispose();
            _porthole3 = controller;
            break;
        }
      });
    } catch (e) {
      controller.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video failed: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// When content drops: React Mode ON = roast, OFF = clean playback
  Future<void> _onWindowContentAdded(int window, io.File file) async {
    // Add to queue
    _addToQueue(window, file);

    // React Mode OFF = just play clean, no drama
    if (!_reactMode) return;

    // Character reaction based on window
    final character = (window == 2) ? 'nigel' : 'terry';
    _playReaction(character, character == 'terry' ? 'grunt' : 'groan');

    // Auto-roast if API keys set
    if (WFLConfig.autoRoastEnabled) {
      final voiceId =
          window == 2 ? _autoRoast.nigelVoiceId : _autoRoast.terryVoiceId;
      _logRiveEvent('roast.start', {'window': window, 'character': character});

      try {
        var roast = await _autoRoast.describeSarcastic(file);

        // Cap at 15 words - TTS stutters, lips go stale otherwise
        final words = roast.split(' ');
        if (words.length > 15) {
          roast = words.sublist(0, 15).join(' ');
        }

        final audioBytes = await _autoRoast.generateSpeech(roast, voiceId,
            character: character);

        if (audioBytes.isNotEmpty) {
          // Save temp audio and play with lip-sync
          final tempDir = io.Directory.systemTemp;
          final audioFile = io.File('${tempDir.path}/roast_$window.mp3');
          await audioFile.writeAsBytes(audioBytes);

          // Save for focus mode
          _lastRoastText = roast;
          _lastRoastAudio = audioFile.path;

          await _playWithLipSync(audioFile.path, character, roast);
          _logRiveEvent('roast.complete',
              {'window': window, 'character': character, 'text': roast});
        }
      } catch (e) {
        debugPrint('Auto-roast error: $e');
        _logRiveEvent('roast.error', {'window': window, 'error': e.toString()});
      }
    }
  }

  void _playReaction(String character, String reaction) {
    // Quick mouth animation for grunt/groan
    final mouths = reaction == 'grunt' ? ['o', 'a', 'x'] : ['e', 'o', 'x'];

    int i = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (i >= mouths.length) {
        timer.cancel();
        return;
      }
      setState(() {
        if (character == 'terry') {
          _terryMouth = mouths[i];
        } else {
          _nigelMouth = mouths[i];
        }
      });
      i++;
    });
  }

  /// Play audio with lip-sync from phoneme cues
  Future<void> _playWithLipSync(
      String audioPath, String character, String text) async {
    // Generate basic cues from text (simplified)
    _currentCues = _generateMouthCues(text);
    _cueIndex = 0;

    // Start audio
    await _voicePlayer.play(DeviceFileSource(audioPath));
    _audioStartTime = DateTime.now();

    // Start lip-sync timer
    _lipSyncTimer?.cancel();
    _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_audioStartTime == null || _cueIndex >= _currentCues.length) {
        timer.cancel();
        setState(() {
          if (character == 'terry') _terryMouth = 'x';
          if (character == 'nigel') _nigelMouth = 'x';
        });
        return;
      }

      final elapsed =
          DateTime.now().difference(_audioStartTime!).inMilliseconds / 1000.0;
      final cue = _currentCues[_cueIndex];

      if (elapsed >= cue.time) {
        setState(() {
          if (character == 'terry') {
            _terryMouth = cue.mouth;
          } else {
            _nigelMouth = cue.mouth;
          }
        });

        // Drive Rive lip shape if loaded
        if (_riveLoaded) {
          final lipValue = _mouthToRiveValue(cue.mouth);
          _setRiveLip(lipValue);
          _setTalking(true);
        }

        _logRiveEvent('input.update', {
          'name': 'lipShape',
          'value': cue.mouth,
          'character': character,
          'action': 'Mouth shape: ${cue.mouth}',
        });
        _cueIndex++;
      }
    });
  }

  /// Convert mouth letter to Rive numeric value
  double _mouthToRiveValue(String mouth) {
    switch (mouth) {
      case 'a':
        return 1;
      case 'e':
        return 2;
      case 'i':
        return 3;
      case 'o':
        return 4;
      case 'u':
        return 5;
      case 'f':
        return 6;
      case 'm':
        return 7;
      case 'l':
        return 8;
      default:
        return 0; // closed/rest
    }
  }

  void _stopLipSync() {
    _lipSyncTimer?.cancel();
    setState(() {
      _terryMouth = 'x';
      _nigelMouth = 'x';
    });
    // Reset Rive lip
    if (_riveLoaded) {
      _setRiveLip(0);
      _setTalking(false);
    }
  }

  /// Generate mouth cues from text (basic vowel mapping)
  List<MouthCue> _generateMouthCues(String text) {
    final cues = <MouthCue>[];
    double time = 0.0;
    const avgCharDuration = 0.08; // ~80ms per character

    for (int i = 0; i < text.length; i++) {
      final char = text[i].toLowerCase();
      String mouth = 'x';

      if ('aáà'.contains(char)) {
        mouth = 'a';
      } else if ('eéè'.contains(char)) {
        mouth = 'e';
      } else if ('iíì'.contains(char)) {
        mouth = 'i';
      } else if ('oóò'.contains(char)) {
        mouth = 'o';
      } else if ('uúù'.contains(char)) {
        mouth = 'u';
      } else if ('fv'.contains(char)) {
        mouth = 'f';
      } else if ('lrw'.contains(char)) {
        mouth = 'l';
      } else if ('mbp'.contains(char)) {
        mouth = 'm';
      } else if (char == ' ') {
        mouth = 'x';
      }

      if (mouth != 'x' || (cues.isNotEmpty && cues.last.mouth != 'x')) {
        cues.add(MouthCue(time, mouth));
      }
      time += avgCharDuration;
    }

    return cues;
  }

  /// Build menu bar configuration with callbacks
  WFLMenuBarConfig _buildMenuConfig() {
    return WFLMenuBarConfig(
      // File menu
      onNewProject: () => debugPrint('New Project'),
      onOpenProject: () => debugPrint('Open Project'),
      onSaveProject: () => debugPrint('Save Project'),
      onSaveProjectAs: () => debugPrint('Save Project As'),
      onExportVideo: () => _startRecording(),
      onExportGif: () => debugPrint('Export GIF'),
      onExportFrames: () => debugPrint('Export Frames'),
      onImportRive: () => debugPrint('Import Rive'),
      onImportAudio: () => debugPrint('Import Audio'),
      onExit: () => SystemNavigator.pop(),

      // Edit menu
      onUndo: () => debugPrint('Undo'),
      onRedo: () => debugPrint('Redo'),
      onCut: () => debugPrint('Cut'),
      onCopy: () => debugPrint('Copy'),
      onPaste: () => debugPrint('Paste'),
      onDelete: () => debugPrint('Delete'),
      onSelectAll: () => debugPrint('Select All'),
      onDeselectAll: () => debugPrint('Deselect All'),

      // View menu
      onZoomIn: () => debugPrint('Zoom In'),
      onZoomOut: () => debugPrint('Zoom Out'),
      onZoomReset: () => debugPrint('Zoom Reset'),
      onToggleFullscreen: () => debugPrint('Toggle Fullscreen'),
      onToggleTimeline: () => debugPrint('Toggle Timeline'),
      onToggleInspector: () => debugPrint('Toggle Inspector'),
      onToggleConsole: () => debugPrint('Toggle Console'),
      onToggleBoneEditor: () => setState(() => _boneEditMode = !_boneEditMode),

      // Playback menu
      onPlay: () { if (_isTalkingRive != null) _isTalkingRive!.value = true; },
      onPause: () { if (_isTalkingRive != null) _isTalkingRive!.value = false; },
      onStop: () { if (_isTalkingRive != null) _isTalkingRive!.value = false; },
      onRewind: () => debugPrint('Rewind'),
      onFastForward: () => debugPrint('Fast Forward'),
      onLoopToggle: () => debugPrint('Toggle Loop'),

      // Animation menu
      onAddKeyframe: () => debugPrint('Add Keyframe'),
      onDeleteKeyframe: () => debugPrint('Delete Keyframe'),
      onGoToNextKeyframe: () => debugPrint('Next Keyframe'),
      onGoToPrevKeyframe: () => debugPrint('Prev Keyframe'),
      onResetPose: () {
        _lip?.value = 0;
        _terryHead?.value = 0;
        _terryEyes?.value = 0;
        _terryRoast?.value = 0;
      },
      onMirrorPose: () => debugPrint('Mirror Pose'),

      // Options menu
      onOpenSettings: () => _showSettingsDialog(),
      onOpenPreferences: () => debugPrint('Open Preferences'),
      onConfigureHotkeys: () => debugPrint('Configure Hotkeys'),
      onManagePlugins: () => debugPrint('Manage Plugins'),

      // Help menu
      onShowAbout: () => _showAboutDialog(),
      onShowDocumentation: () => debugPrint('Show Documentation'),
      onShowKeyboardShortcuts: () => _showKeyboardShortcutsDialog(),
      onCheckForUpdates: () => debugPrint('Check for Updates'),
      onReportBug: () => debugPrint('Report Bug'),

      // State getters
      isPlaying: () => _isTalkingRive?.value ?? false,
      isLooping: () => true,
      canUndo: () => false,
      canRedo: () => false,
      isFullscreen: () => false,
      isTimelineVisible: () => true,
      isInspectorVisible: () => true,
      isConsoleVisible: () => false,
      isBoneEditorVisible: () => _boneEditMode,
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D30),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        content: const SizedBox(
          width: 400,
          child: Text('Settings panel coming soon...', style: TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D30),
        title: const Text('About WFL Animator', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WFL Animator v1.0.0', style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 8),
            Text('Wooking for Love Animation Tool', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text('Powered by Rive 0.14.0', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showKeyboardShortcutsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D30),
        title: const Text('Keyboard Shortcuts', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView(
            children: const [
              _ShortcutRow('Space', 'Play/Pause'),
              _ShortcutRow('0-8', 'Set mouth shape'),
              _ShortcutRow('Left/Right', 'Turn head'),
              _ShortcutRow('Shift+B', 'Toggle bone editor'),
              _ShortcutRow('Shift+W', 'Toggle warp mode'),
              _ShortcutRow('Shift+F', 'Focus mode'),
              _ShortcutRow('F1-F3', 'Button controls'),
              _ShortcutRow('Ctrl+S', 'Save project'),
              _ShortcutRow('Ctrl+E', 'Export video'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Request focus after build to avoid FocusNode timing issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: false, // Defer focus to avoid RenderBox errors
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // Menu bar
            WFLMenuBar(config: _buildMenuConfig()),

            // Top bar: React Mode toggle + Save Preset
            _buildTopBar(),

            // Main content: Cockpit + Queue
            Expanded(
              child: Row(
                children: [
                  // Cockpit + Volume (left)
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Cockpit or Bone Editor
                        Expanded(
                          child: _boneEditMode
                              // BONE EDIT MODE: Draw bones directly
                              ? BoneEditor(
                                  key: _boneEditorKey,
                                  backgroundImage:
                                      'assets/backgrounds/spaceship_iso.png',
                                  onSkeletonChanged: (skeleton) {
                                    _skeleton = skeleton;
                                    debugPrint(
                                        'Bones: ${skeleton.bones.keys.join(", ")}');
                                  },
                                )
                              : Center(
                                  child: GestureDetector(
                                    onTapDown: _onCockpitTap,
                                    child: _riveLoaded && _riveController != null
                                        // RIVE MODE: Full animated cockpit
                                        ? SizedBox(
                                            width: double.infinity,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.9,
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: SizedBox(
                                                width: 2000,
                                                height: 1000,
                                                child: rive.RiveWidget(
                                                    controller: _riveController!,
                                                    fit: rive.Fit.contain),
                                              ),
                                            ),
                                          )
                                        // PNG FALLBACK: Layer stacking mode
                                        : AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: ClipRect(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  // WARP MODE: Full-screen video behind everything
                                                  if (_isWarp &&
                                                      _warpPlayer != null &&
                                                      _warpPlayer!
                                                          .value.isInitialized)
                                                    Positioned.fill(
                                                      child: ColorFiltered(
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                          Colors.black
                                                              .withValues(
                                                                  alpha: 0.3),
                                                          BlendMode.darken,
                                                        ),
                                                        child: VideoPlayer(
                                                            _warpPlayer!),
                                                      ),
                                                    ),

                                                  // Normal background (dimmed in warp)
                                                  Positioned.fill(
                                                    child: Opacity(
                                                      opacity:
                                                          _isWarp ? 0.0 : 1.0,
                                                      child: _spaceship,
                                                    ),
                                                  ),

                                                  // Ship overlay (always on top)
                                                  Positioned.fill(
                                                      child: _buttonsPanel),
                                                  _buildPortholes(),
                                                  Positioned(
                                                    left: 50,
                                                    bottom: 0,
                                                    child: _buildCharacter(
                                                        'terry',
                                                        _terryBody,
                                                        _terryMouth),
                                                  ),
                                                  Positioned(
                                                    right: 50,
                                                    bottom: 0,
                                                    child: _buildCharacter(
                                                        'nigel',
                                                        _nigelBody,
                                                        _nigelMouth),
                                                  ),
                                                  Positioned(
                                                    bottom: 0,
                                                    left: 0,
                                                    right: 0,
                                                    child: _table,
                                                  ),
                                                  Positioned(
                                                    bottom: 10,
                                                    right: 10,
                                                    child: _buildHotkeyHints(),
                                                  ),

                                                  // WARP HUD - green text overlay
                                                  if (_isWarp) _buildWarpHUD(),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                        ),

                        // Volume slider under cockpit
                        _buildVolumeSlider(),
                      ],
                    ),
                  ),

                  // Queue panel (middle-right)
                  _buildQueuePanel(),

                  // Agent Chat panel (far right)
                  WFLAgentChat(
                    config: _buildAgentChatConfig(),
                    isExpanded: _chatExpanded,
                    onToggleExpand: () => setState(() => _chatExpanded = !_chatExpanded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build configuration for agent chat
  AgentChatConfig _buildAgentChatConfig() {
    return AgentChatConfig(
      // Animation controls
      setMouthShape: (v) => _setRiveLip(v),
      setHeadTurn: (v) => _setTerryHead(v / 40), // Convert degrees to -1..1
      setEyeState: (v) => _setTerryEyes(v),
      setRoastTone: (v) => _setTerryRoast(v),
      setTalking: (v) => _setTalking(v),
      resetPose: () {
        _setRiveLip(0);
        _setTerryHead(0);
        _setTerryEyes(0);
        _setTerryRoast(0);
        _setTalking(false);
        setState(() {
          _terryMouth = 'x';
          _nigelMouth = 'x';
        });
      },

      // Playback controls
      play: () => _voicePlayer.resume(),
      pause: () => _voicePlayer.pause(),
      stop: () => _voicePlayer.stop(),

      // View controls
      toggleBoneEditor: () => setState(() => _boneEditMode = !_boneEditMode),
      toggleFullscreen: () => _toggleWarpMode(),
      zoomIn: () {}, // TODO: implement zoom
      zoomOut: () {}, // TODO: implement zoom

      // File operations
      saveProject: () => _savePreset('QuickSave'),
      exportVideo: () => _exportVideo(),
      openProject: () {}, // TODO: implement open

      // Settings
      openSettings: () => _showSettingsDialog(),

      // State getters
      getMouthShape: () => _lip?.value ?? 0,
      getHeadTurn: () => (_terryHead?.value ?? 0) * 40, // Convert -1..1 to degrees
      getEyeState: () => _terryEyes?.value ?? 0,
      getRoastTone: () => _terryRoast?.value ?? 0,
      isTalking: () => _isTalkingRive?.value ?? false,
      isPlaying: () => _voicePlayer.state == PlayerState.playing,
    );
  }

  /// Top bar with React Mode toggle and Save Preset
  Widget _buildTopBar() {
    return Container(
      height: 50,
      color: const Color(0xFF2a2a3e),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // React Mode toggle
          const Text('React Mode', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          Switch(
            value: _reactMode,
            onChanged: (v) => setState(() => _reactMode = v),
            activeColor: Colors.greenAccent,
          ),
          Text(
            _reactMode ? 'ON - Roast + Lip-sync' : 'OFF - Clean playback',
            style: TextStyle(
              color: _reactMode ? Colors.greenAccent : Colors.grey,
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 24),

          // LIVE MIC button - hold to talk, release to roast
          GestureDetector(
            onTap: _toggleLiveMic,
            onLongPressStart: (_) => _startLiveMicRecording(),
            onLongPressEnd: (_) => _stopLiveMicRecording(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isRecordingMic
                    ? Colors.orange
                    : (_isLiveMicOn
                        ? Colors.orange.shade800
                        : const Color(0xFF3a3a4e)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRecordingMic
                      ? Colors.orange.shade300
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRecordingMic ? Icons.mic : Icons.mic_none,
                    color: _isLiveMicOn ? Colors.white : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isRecordingMic
                        ? 'LISTENING...'
                        : (_isLiveMicOn ? 'MIC ON' : 'LIVE'),
                    style: TextStyle(
                      color: _isLiveMicOn ? Colors.white : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // REC button - 30fps capture
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : const Color(0xFF3a3a4e),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      _isRecording ? Colors.red.shade300 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.white : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording ? 'REC ${_recordingSeconds}s' : 'REC',
                    style: TextStyle(
                      color: _isRecording ? Colors.white : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Save Preset button
          TextButton.icon(
            onPressed: _showSavePresetDialog,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Preset'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),

          // Load Preset button
          TextButton.icon(
            onPressed: _showLoadPresetDialog,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Load'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),

          const SizedBox(width: 16),

          // YouTube connect/disconnect
          TextButton.icon(
            onPressed: _toggleYouTube,
            icon: Icon(
              WFLUploader.isYouTubeConnected ? Icons.link : Icons.link_off,
              size: 18,
              color:
                  WFLUploader.isYouTubeConnected ? Colors.green : Colors.grey,
            ),
            label: Text(
              WFLUploader.isYouTubeConnected ? 'YouTube ✓' : 'Connect YouTube',
              style: TextStyle(
                color: WFLUploader.isYouTubeConnected
                    ? Colors.green
                    : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Queue panel on the right - 5-second thumbnails, drag to shuffle
  Widget _buildQueuePanel() {
    return Container(
      width: 200,
      color: const Color(0xFF1a1a2e),
      child: Column(
        children: [
          // Queue header
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF2a2a3e),
            child: Row(
              children: [
                const Text('Queue',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_roastQueue.length}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          // Queue list (drag to reorder)
          Expanded(
            child: _roastQueue.isEmpty
                ? const Center(
                    child: Text(
                      'Drop videos\nto queue',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _roastQueue.length,
                    onReorder: _reorderQueue,
                    itemBuilder: (context, index) {
                      final item = _roastQueue[index];
                      final isPlaying =
                          _isPlayingQueue && index == _currentQueueIndex;
                      return _buildQueueItem(item, index, isPlaying);
                    },
                  ),
          ),

          // Play Queue button
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _roastQueue.isEmpty ? null : _playQueue,
                    icon: Icon(_isPlayingQueue ? Icons.stop : Icons.play_arrow),
                    label: Text(_isPlayingQueue ? 'Stop' : 'Play Queue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isPlayingQueue ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _roastQueue.isEmpty ? null : _clearQueue,
                  icon: const Icon(Icons.clear_all),
                  color: Colors.grey,
                  tooltip: 'Clear queue',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(QueueItem item, int index, bool isPlaying) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPlaying
            ? Colors.green.withValues(alpha: 0.3)
            : const Color(0xFF2a2a3e),
        borderRadius: BorderRadius.circular(8),
        border: isPlaying ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: item.thumbnail != null
              ? Image.memory(item.thumbnail!,
                  width: 50, height: 50, fit: BoxFit.cover)
              : Container(width: 50, height: 50, color: Colors.grey.shade800),
        ),
        title: Text(
          item.filename,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Window ${item.window}',
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 16),
          color: Colors.grey,
          onPressed: () => _removeFromQueue(index),
        ),
      ),
    );
  }

  void _reorderQueue(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _roastQueue.removeAt(oldIndex);
      _roastQueue.insert(newIndex, item);
    });
  }

  void _removeFromQueue(int index) {
    setState(() => _roastQueue.removeAt(index));
  }

  void _clearQueue() {
    setState(() => _roastQueue.clear());
  }

  /// Play queue back-to-back, no stutter
  Future<void> _playQueue() async {
    if (_isPlayingQueue) {
      setState(() => _isPlayingQueue = false);
      return;
    }

    setState(() {
      _isPlayingQueue = true;
      _currentQueueIndex = 0;
    });

    for (int i = 0; i < _roastQueue.length && _isPlayingQueue; i++) {
      setState(() => _currentQueueIndex = i);
      final item = _roastQueue[i];

      // Load video into window
      await _loadPortholeVideo(item.window, io.File(item.path));

      // React if enabled
      if (_reactMode) {
        await _onWindowContentAdded(item.window, io.File(item.path));
      }

      // Wait for roast to finish (or 5 seconds if no react)
      await Future.delayed(Duration(seconds: _reactMode ? 8 : 5));
    }

    setState(() => _isPlayingQueue = false);
  }

  /// Add to queue when dropping video
  void _addToQueue(int window, io.File file, {Uint8List? thumbnail}) {
    setState(() {
      _roastQueue.add(QueueItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: file.path,
        filename: file.path.split('/').last.split('\\').last,
        window: window,
        thumbnail: thumbnail,
      ));
    });
  }

  /// Save preset dialog
  Future<void> _showSavePresetDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text('Save Preset', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: false,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nigel Roast Pack',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _savePreset(name);
    }
  }

  Future<void> _savePreset(String name) async {
    // Save current window configs + queue
    final preset = {
      'name': name,
      'queue':
          _roastQueue.map((q) => {'path': q.path, 'window': q.window}).toList(),
      'reactMode': _reactMode,
    };
    // In real app, save to SharedPreferences or file
    debugPrint('Saved preset: $name with ${_roastQueue.length} clips');
  }

  Future<void> _showLoadPresetDialog() async {
    // In real app, load from SharedPreferences
    // For now, show placeholder
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text('Load Preset', style: TextStyle(color: Colors.white)),
        content: const Text('No presets saved yet.\nSave a preset first!',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Volume slider: whisper to TikTok loud
  Widget _buildVolumeSlider() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(
            _volume < 0.3
                ? Icons.volume_mute
                : (_volume < 0.7 ? Icons.volume_down : Icons.volume_up),
            color: Colors.white54,
            size: 20,
          ),
          Expanded(
            child: Slider(
              value: _volume,
              min: 0,
              max: 1,
              onChanged: (v) {
                setState(() => _volume = v);
                _voicePlayer.setVolume(v);
              },
              activeColor: Colors.greenAccent,
              inactiveColor: Colors.grey.shade700,
            ),
          ),
          Text(
            _volume < 0.3 ? 'Whisper' : (_volume < 0.7 ? 'Normal' : 'Loud'),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(width: 12),
          // Export button
          ElevatedButton.icon(
            onPressed: _exportVideo,
            icon: const Icon(Icons.movie, size: 16),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          // Export & Post - the one-click nuclear option
          ElevatedButton.icon(
            onPressed: _exportAndPost,
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: Text('Post #${WFLUploader.roastNumber}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  /// FFmpeg export - show quality preset picker
  Future<void> _exportVideo() async {
    // CRITICAL: Mute warp player during export to prevent audio leak
    if (_isWarp && _warpPlayer != null) {
      _warpPlayer!.setVolume(0.0);
    }

    // Pick quality preset
    final preset = await showDialog<ExportPreset>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title:
            const Text('Export Quality', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _exportOption(ctx, ExportPreset.youtube),
            _exportOption(ctx, ExportPreset.stream),
            _exportOption(ctx, ExportPreset.gif),
          ],
        ),
      ),
    );

    if (preset == null) return;

    try {
      // Ask user for save location via text input
      final nameController = TextEditingController(
          text: 'roast_${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;

      final fileName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a3e),
          title: const Text('Save As', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'roast_001',
              hintStyle: TextStyle(color: Colors.grey),
              suffixText: '.mp4',
              suffixStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nameController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (fileName == null || fileName.isEmpty) return;

      // Show progress again
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a3e),
          title: Text('Exporting ${preset.name}...',
              style: const TextStyle(color: Colors.white)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator()],
          ),
        ),
      );

      // Save to Documents/WFL_Exports/
      final docsDir = io.Directory(
          '${io.Platform.environment['USERPROFILE']}\\Documents\\WFL_Exports');
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      final outputPath = '${docsDir.path}\\$fileName.mp4';

      // Use temp for frames
      final tempDir = await getTemporaryDirectory();
      final framesPath = '${tempDir.path}/wfl_frames';

      // Clean frames folder first - crashes if leftover from last render
      final framesDir = io.Directory(framesPath);
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      await framesDir.create();

      // FFmpeg export with preset
      final result = await io.Process.run('ffmpeg', [
        '-y',
        '-framerate',
        '${preset.fps}',
        '-i',
        '$framesPath/%04d.png',
        '-vcodec',
        'libx264',
        '-s',
        preset.resolution,
        '-pix_fmt',
        'yuv420p',
        '-crf',
        '${preset.crf}',
        '-af',
        'loudnorm',
        outputPath,
      ]);

      if (!mounted) return;
      Navigator.pop(context);

      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $outputPath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${result.stderr}')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('FFmpeg not found. Install FFmpeg first.')),
      );
    }
  }

  Widget _exportOption(BuildContext ctx, ExportPreset preset) {
    return ListTile(
      title: Text(preset.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text('${preset.resolution} • ${preset.description}',
          style: const TextStyle(color: Colors.grey, fontSize: 11)),
      onTap: () => Navigator.pop(ctx, preset),
    );
  }

  /// Export & Post - one click: render → YouTube → share sheet
  /// Done in 8-12 seconds. Zero backend.
  Future<void> _exportAndPost() async {
    // CRITICAL: Mute warp player during export to prevent audio leak
    if (_isWarp && _warpPlayer != null) {
      _warpPlayer!.setVolume(0.0);
    }

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Colors.green),
            const SizedBox(width: 8),
            Text('Posting Roast #${WFLUploader.roastNumber}',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Rendering → YouTube → Share Sheet',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      // Use temp directory - antivirus won't lock it
      final tempDir = await getTemporaryDirectory();
      final framesPath = '${tempDir.path}/wfl_frames';
      final outputPath =
          '${tempDir.path}/output_roast_${WFLUploader.roastNumber}.mp4';

      // 1. Export video (YouTube preset - 1080x720)
      await io.Process.run('ffmpeg', [
        '-y',
        '-framerate',
        '30',
        '-i',
        '$framesPath/%04d.png',
        '-vcodec',
        'libx264',
        '-s',
        '1080x720',
        '-pix_fmt',
        'yuv420p',
        '-crf',
        '18',
        '-af',
        'loudnorm',
        outputPath,
      ]);

      final videoFile = io.File(outputPath);
      if (!await videoFile.exists()) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Check FFmpeg.')),
        );
        return;
      }

      // 2. Upload to YouTube + open share sheet
      final results = await WFLUploader.exportAndPost(
        videoFile,
        title: 'Terry & Nigel roast TikTok #${WFLUploader.roastNumber}',
      );

      Navigator.pop(context);

      // 3. Show results
      final youtubeUrl = results['youtube'];
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a3e),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Posted!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (youtubeUrl != null) ...[
                const Text('YouTube:', style: TextStyle(color: Colors.grey)),
                SelectableText(youtubeUrl,
                    style: const TextStyle(color: Colors.blue)),
                const SizedBox(height: 8),
              ],
              const Text('Share sheet opened for TikTok/Reels/Shorts',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nice'),
            ),
          ],
        ),
      );

      setState(() {}); // Update roast number
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post failed: $e')),
      );
    }
  }

  Widget _buildHotkeyHints() {
    // Show focus hint if keyboard lost focus
    if (!_hasFocus) {
      return GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Click cockpit to control',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('F1 Thrusters',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
          const Text('F2 Warp',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
          const Text('F3 Shields',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
          if (!_isWarp)
            const Text('SHIFT+W Warp Mode',
                style: TextStyle(fontSize: 10, color: Colors.green)),
          const Text('SHIFT+F Focus Mode',
              style: TextStyle(fontSize: 10, color: Colors.cyan)),
        ],
      ),
    );
  }

  /// WARP HUD - green text, fake spaceship display
  Widget _buildWarpHUD() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top scanline
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                height: 1,
                color: Colors.green.withValues(alpha: 0.3),
              ),
            ),

            // Bottom HUD bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7)
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Warp speed
                    Text(
                      'WARP ${_warpSpeed.toStringAsFixed(2)}c',
                      style: TextStyle(
                        color: Colors.green.shade400,
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 30),

                    // Destination
                    Text(
                      'DEST: VIRAL CLIP',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),

                    const Spacer(),

                    // Exit hint
                    Text(
                      '[SHIFT+W] EXIT WARP',
                      style: TextStyle(
                        color: Colors.green.shade500,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Corner brackets (HUD frame)
            ..._buildHUDCorners(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHUDCorners() {
    const cornerSize = 30.0;
    const color = Colors.green;
    const thickness = 2.0;

    return [
      // Top-left
      Positioned(
        top: 10,
        left: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 10,
        right: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 40,
        left: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 40,
        right: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPortholes() {
    return Stack(
      children: [
        // Porthole 1 - Left
        Positioned(
          left: 100,
          top: 80,
          child: _buildPorthole(1, _porthole1),
        ),
        // Porthole 2 - Center
        Positioned(
          left: 0,
          right: 0,
          top: 60,
          child: Center(child: _buildPorthole(2, _porthole2)),
        ),
        // Porthole 3 - Right
        Positioned(
          right: 100,
          top: 80,
          child: _buildPorthole(3, _porthole3),
        ),
      ],
    );
  }

  Widget _buildPorthole(int index, VideoPlayerController? controller) {
    const size = 150.0;

    return GestureDetector(
      onTap: () => _onPortholeDropped(index),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade700, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          // ClipOval for circular porthole
          child: controller != null && controller.value.isInitialized
              ? VideoPlayer(controller)
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.grey.shade600,
                      size: 40,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCharacter(String name, Image body, String mouth) {
    return SizedBox(
      width: 300,
      height: 400,
      child: Stack(
        children: [
          // Body
          Positioned.fill(child: body),

          // Eyes (Nigel only)
          if (name == 'nigel')
            Positioned(
              left: 60,
              top: 80,
              child: Image.asset(
                'assets/characters/nigel/eyes/$_nigelEyes.png',
                width: 180,
                height: 60,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Mouth layer (swapped based on current phoneme)
          Positioned(
            left: 80,
            top: 150,
            child: Image.asset(
              'assets/characters/$name/mouth_shapes/$mouth.png',
              width: 140,
              height: 80,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mouth cue for lip-sync timing
class MouthCue {
  final double time;
  final String mouth;

  MouthCue(this.time, this.mouth);
}

/// Button hit region for tap detection
class ButtonHitRegion {
  final double x;
  final double y;
  final double radius;
  final String name;

  const ButtonHitRegion(this.x, this.y, this.radius, this.name);
}

/// Queue item for back-to-back roasts
class QueueItem {
  final String id;
  final String path;
  final String filename;
  final int window;
  final Uint8List? thumbnail;

  QueueItem({
    required this.id,
    required this.path,
    required this.filename,
    required this.window,
    this.thumbnail,
  });
}

/// Export quality presets
class ExportPreset {
  final String name;
  final String resolution;
  final int fps;
  final int crf;
  final String description;

  const ExportPreset(
      this.name, this.resolution, this.fps, this.crf, this.description);

  static const youtube =
      ExportPreset('YouTube', '1080x720', 30, 18, '~120MB/min, crisp');
  static const stream =
      ExportPreset('Stream', '1080x720', 30, 24, '~80MB/min, fast');
  static const gif =
      ExportPreset('GIF Loop', '720x480', 15, 28, '~10MB, viral bait');
}

/// Shortcut row for keyboard shortcuts dialog
class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutRow(this.shortcut, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
