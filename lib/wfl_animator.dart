import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:video_player/video_player.dart';
// file_picker removed - using drag-and-drop instead
// RIVE DISABLED: Using custom bone animation to avoid Windows path length issues
// import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'rive_stub.dart'; // Stub classes when Rive is disabled
import 'package:path_provider/path_provider.dart';
// Stubbed for Windows build - mic recording not supported
import 'record_stub.dart';
import 'wfl_controller.dart';
import 'wfl_config.dart';
import 'wfl_uploader.dart';
import 'wfl_focus_mode.dart';
import 'wfl_data_binding.dart';
import 'wfl_websocket.dart';
import 'wfl_image_resizer.dart';
import 'wfl_animations.dart';
import 'sound_effects.dart';
import 'bone_animation.dart';

/// Rive input names - enum prevents typos that freeze the mouth forever
/// (Legacy - kept for backwards compatibility with old .riv files)
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

class _WFLAnimatorState extends State<WFLAnimator> with TickerProviderStateMixin {
  // Baked static images - loaded once, never again
  late final Image _spaceship;
  late final Image _terryBody;
  late final Image _nigelBody;
  late final Image _table;
  late final Image _buttonsPanel;

  // Rive bone animation - replaces static PNGs
  RiveFile? _riveFile;
  Artboard? _terryArtboard;
  Artboard? _nigelArtboard;
  StateMachineController? _terryStateMachine;
  StateMachineController? _nigelStateMachine;
  bool _riveLoaded = false;

  // Custom bone animation - alternative to Rive
  Skeleton? _terrySkeleton;
  Skeleton? _nigelSkeleton;
  bool _skeletonsLoaded = false;
  String _terryAnimation = 'idle';
  String _nigelAnimation = 'idle';
  final GlobalKey<BoneAnimatorWidgetState> _terryBoneKey = GlobalKey();
  final GlobalKey<BoneAnimatorWidgetState> _nigelBoneKey = GlobalKey();

  // Audio player for voice lines
  final AudioPlayer _voicePlayer = AudioPlayer();

  // Three porthole video controllers
  VideoPlayerController? _porthole1;
  VideoPlayerController? _porthole2;
  VideoPlayerController? _porthole3;

  // Current mouth shape for lip-sync
  String _terryMouth = 'x';
  String _nigelMouth = 'x';

  // Lip-sync timer
  Timer? _lipSyncTimer;
  List<MouthCue> _currentCues = [];
  int _cueIndex = 0;
  DateTime? _audioStartTime;

  // Auto-roast pipeline
  late final WFLAutoRoast _autoRoast;

  // Rive controller for cockpit (legacy)
  StateMachineController? _riveController;
  SMINumber? _buttonState;
  // Note: String inputs don't exist in Rive state machines - removed _btnTarget
  SMIBool? _isTalking;

  // Data Binding controllers (new API)
  WFLCharacterController? _terryController;
  WFLCharacterController? _nigelController;

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

  // ============ SIMPLE_ANIMATIONS IDLE SYSTEM ============
  // MovieTweens from wfl_animations.dart handle organic multi-property animation
  // MirrorAnimationBuilder in build() handles smooth looping automatically
  // Only blink state needs manual timer (random intervals can't use MovieTween)
  Timer? _blinkTimer;
  String _terryBlinkState = 'open'; // open, half, closed
  String _nigelBlinkState = 'open';
  final _random = Random();

  // Character component transform state (resize + position)
  // Each component (body, eyes, mouth) has independent scale and offset

  // Terry components
  double _terryBodyScale = 1.0;
  Offset _terryBodyOffset = Offset.zero;
  double _terryEyesScale = 1.0;
  Offset _terryEyesOffset = Offset.zero;
  double _terryMouthScale = 1.0;
  Offset _terryMouthOffset = Offset.zero;

  // Nigel components
  double _nigelBodyScale = 1.0;
  Offset _nigelBodyOffset = Offset.zero;
  double _nigelEyesScale = 1.0;
  Offset _nigelEyesOffset = Offset.zero;
  double _nigelMouthScale = 1.0;
  Offset _nigelMouthOffset = Offset.zero;

  // Animation state for PNG fallback character rendering
  // These are used by _buildPngCharacter when Rive is not available
  double _terryEyeX = 0.0;
  double _terryEyeY = 0.0;
  double _nigelEyeX = 0.0;
  double _nigelEyeY = 0.0;
  double _terryHeadBob = 0.0;
  double _nigelHeadBob = 0.0;
  double _terrySway = 0.0;
  double _nigelSway = 0.0;
  double _terryLean = 0.0;
  double _nigelLean = 0.0;
  double _breathOffset = 0.0;

  // Scale limits
  static const double _minScale = 0.3;
  static const double _maxScale = 3.0;
  static const double _defaultScale = 1.0;

  // Subtitle system
  String _subtitleText = '';
  String _subtitleSpeaker = '';  // 'terry', 'nigel', or '' for narrator
  bool _subtitleVisible = false;
  Timer? _subtitleTimer;

  // SFX Panel
  bool _sfxPanelExpanded = true;  // Start expanded so user sees buttons

  // NOTE: HeadBob, Sway, Lean now handled by MirrorAnimationBuilder + MovieTween
  // See _buildCharacterWithComponents() and _buildPngCharacter() for usage

  // Show Mode - auto-commentary
  bool _showMode = false;
  Timer? _showModeTimer;
  int _currentSpeaker = 0; // 0 = terry, 1 = nigel, alternates
  bool _isGeneratingCommentary = false;

  // Dialogue playback state
  bool _dialoguePlaying = false;
  bool _dialoguePaused = false;
  Timer? _dialogueTimer;
  int _dialogueIndex = 0;

  // Sample dialogue lines for demo
  static const List<Map<String, String>> _sampleDialogue = [
    {'speaker': 'terry', 'text': 'Yo, welcome to **Wooking for Love**! I\'m Terry, your host with the most!'},
    {'speaker': 'nigel', 'text': 'And I\'m Nigel. *Reluctantly* here to provide... commentary.'},
    {'speaker': 'terry', 'text': 'Tonight we got some FIRE contestants lined up!'},
    {'speaker': 'nigel', 'text': 'Indeed. Though I suspect the only thing *fire* will be my scathing observations.'},
    {'speaker': 'terry', 'text': 'Bruh, you gotta chill! This is about LOVE!'},
    {'speaker': 'nigel', 'text': 'Love? In THIS economy? **Doubtful.**'},
    {'speaker': 'terry', 'text': 'Aight let\'s bring out our first contestant!'},
    {'speaker': 'nigel', 'text': 'Brace yourselves. Here comes the *cringe*.'},
    {'speaker': 'terry', 'text': 'Yo that outfit is straight BUSSIN!'},
    {'speaker': 'nigel', 'text': 'If by *bussin* you mean a fashion disaster, then yes.'},
    {'speaker': 'terry', 'text': 'Nigel why you always gotta be so negative?'},
    {'speaker': 'nigel', 'text': 'I prefer the term **realistic**, Terry.'},
  ];

  // Reaction animations
  String _terryReaction = 'neutral'; // neutral, laughing, shocked, facepalm, pointing, thinking
  String _nigelReaction = 'neutral';
  Timer? _reactionTimer;

  // Character-specific facial feature positions
  static const Map<String, Map<String, dynamic>> _characterConfig = {
    'terry': {
      'mouthX': 95.0,
      'mouthY': 175.0,
      'mouthWidth': 110.0,
      'mouthHeight': 60.0,
      'eyesX': 70.0,
      'eyesY': 120.0,
      'eyesWidth': 160.0,
      'eyesHeight': 50.0,
      'hasEyes': false, // Terry's eyes are built into layers
    },
    'nigel': {
      'mouthX': 100.0,
      'mouthY': 185.0,
      'mouthWidth': 100.0,
      'mouthHeight': 55.0,
      'eyesX': 75.0,
      'eyesY': 130.0,
      'eyesWidth': 150.0,
      'eyesHeight': 45.0,
      'hasEyes': true, // Nigel has separate eye sprites
      'mouthFullFrame': true, // Nigel's mouth shapes are full-frame 2368x1792 PNGs (already positioned)
      'bodyAspectRatio': 1376.0 / 752.0, // actual body image aspect ratio (1.83:1 = wider than tall)
    },
  };

  // Layer stacking order for each character (bottom to top)
  // Based on Python compositor: nigel_compositor.py LAYER_ORDER
  static const Map<String, List<String>> _layerOrder = {
    'nigel': [
      'layer_05', // Back arm left
      'layer_06', // Back arm right
      'layer_04', // Torso/jacket
      'layer_02', // Head background
      'layer_03', // Face
      'layer_07', // Mid arms
      'layer_08',
      'layer_09', // Front arms
      'layer_10',
      'layer_11', // Hands
      'layer_12',
      'layer_13', // Legs
      'layer_14',
      'layer_15', // Robot arm
      'layer_01', // Hat on top
    ],
    'terry': [
      'layer_05', // Back elements
      'layer_06',
      'layer_04',
      'layer_02',
      'layer_03',
      'layer_07',
      'layer_08',
      'layer_09',
      'layer_10',
      'layer_11',
      'layer_12',
      'layer_13',
      'layer_14',
      'layer_15',
      'layer_16',
      'layer_17',
      'layer_18',
      'layer_19',
      'layer_20',
      'layer_01', // Top layer
    ],
  };

  // WARP MODE - flying through video
  bool _isWarp = false;
  VideoPlayerController? _warpPlayer;
  double _warpSpeed = 0.87; // c units

  // FLYTHROUGH MODE - single video behind all 3 portholes as masks
  bool _flythroughMode = false;
  VideoPlayerController? _flythroughVideo;

  // FOCUS MODE - which window is focused for zoom roast
  int? _focusWindow;
  String? _lastRoastText;
  String? _lastRoastAudio;

  // Track if cockpit has keyboard focus (for hotkey hint)
  bool _hasFocus = true;

  // LIVE MIC MODE - record user voice, transcribe, roast back
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isLiveMicOn = false;
  bool _isRecordingMic = false;
  bool _hasMicPermission = false;
  String? _lastTranscription;

  // WebSocket server connection
  late final WFLWebSocket _wsClient;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();

    // Bake all static images ONCE
    _spaceship = Image.asset('assets/backgrounds/spaceship_iso.png');
    // Use transparent full-body character images (for seated behind table)
    _terryBody = Image.asset('assets/characters/terry/terry sitting transp/Terry, transparent background.PNG');
    _nigelBody = Image.asset('assets/characters/nigel/nigel transparent/TRANSPARENT NIGEL.PNG');
    _table = Image.asset('assets/backgrounds/table.png');
    _buttonsPanel = Image.asset('assets/backgrounds/buttons_panel.png');

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

    // Start blink timer (simple_animations handles the rest via MirrorAnimationBuilder)
    _startBlinkTimer();

    // Track focus changes for hotkey hint
    _focusNode.addListener(_onFocusChange);

    // Request focus after first frame to avoid layout issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    // Connect to WFL server via WebSocket
    _wsClient = WFLWebSocket(
      onCommand: _handleServerCommand,
      onConnectionChanged: (connected) {
        setState(() => _wsConnected = connected);
      },
    );
    _wsClient.connect();

    // Load Rive bone animations for characters
    _loadRiveAnimations();

    // Also load custom skeletons (fallback when Rive doesn't work)
    _loadSkeletons();

    // Start background music on app open (dating show vibe!)
    SoundEffects().startBackgroundMusic();

    // Demo subtitle sequence (shows subtitle system works)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        showSubtitle('terry', "G'day legends! Welcome to **Wooking for Love**!");
      }
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        showSubtitle('nigel', "Indeed. I must say, this is *quite* the peculiar situation.");
      }
    });
  }

  /// Load Rive file and initialize character artboards with bone animations
  Future<void> _loadRiveAnimations() async {
    try {
      // Initialize Rive runtime first (required before importing files)
      await RiveFile.initialize();

      // Load the Rive file
      final data = await rootBundle.load('assets/wfl.riv');
      final file = RiveFile.import(data);
      _riveFile = file;

      // Check if file has artboards
      Artboard? mainArtboard;
      try {
        mainArtboard = file.mainArtboard;
        debugPrint('Rive file loaded. Main artboard: ${mainArtboard?.name}');
      } catch (e) {
        debugPrint('Rive file has no main artboard: $e');
        // File loaded but no usable artboards - fall back to PNG
        return;
      }

      // Get artboards for characters
      // Try character-specific artboards first, then use main artboard instances
      final terryArtboard = file.artboardByName('terry');
      final nigelArtboard = file.artboardByName('nigel');

      debugPrint('Terry artboard: ${terryArtboard != null ? "found" : "not found"}');
      debugPrint('Nigel artboard: ${nigelArtboard != null ? "found" : "not found"}');

      // Use character artboards if found, otherwise create instances of main artboard
      if (terryArtboard != null) {
        _terryArtboard = terryArtboard;
      } else if (mainArtboard != null) {
        try {
          _terryArtboard = mainArtboard.instance();
        } catch (e) {
          debugPrint('Could not create Terry artboard instance: $e');
        }
      }

      if (nigelArtboard != null) {
        _nigelArtboard = nigelArtboard;
      } else if (mainArtboard != null) {
        try {
          _nigelArtboard = mainArtboard.instance();
        } catch (e) {
          debugPrint('Could not create Nigel artboard instance: $e');
        }
      }

      // Initialize state machines for bone animation control
      if (_terryArtboard != null) {
        // Try multiple state machine names
        _terryStateMachine = StateMachineController.fromArtboard(_terryArtboard!, 'character')
            ?? StateMachineController.fromArtboard(_terryArtboard!, 'cockpit')
            ?? StateMachineController.fromArtboard(_terryArtboard!, 'talker')
            ?? StateMachineController.fromArtboard(_terryArtboard!, 'State Machine 1');

        if (_terryStateMachine != null) {
          _terryArtboard!.addController(_terryStateMachine!);
          debugPrint('Terry state machine: ${_terryStateMachine!.stateMachine.name}');
          _terryController = WFLCharacterController(
            characterName: 'terry',
            artboard: _terryArtboard!,
            stateMachineName: _terryStateMachine!.stateMachine.name,
          );
        } else {
          debugPrint('Terry: No state machine found');
        }
      }

      if (_nigelArtboard != null) {
        _nigelStateMachine = StateMachineController.fromArtboard(_nigelArtboard!, 'character')
            ?? StateMachineController.fromArtboard(_nigelArtboard!, 'cockpit')
            ?? StateMachineController.fromArtboard(_nigelArtboard!, 'talker')
            ?? StateMachineController.fromArtboard(_nigelArtboard!, 'State Machine 1');

        if (_nigelStateMachine != null) {
          _nigelArtboard!.addController(_nigelStateMachine!);
          debugPrint('Nigel state machine: ${_nigelStateMachine!.stateMachine.name}');
          _nigelController = WFLCharacterController(
            characterName: 'nigel',
            artboard: _nigelArtboard!,
            stateMachineName: _nigelStateMachine!.stateMachine.name,
          );
        } else {
          debugPrint('Nigel: No state machine found');
        }
      }

      if (_terryArtboard != null || _nigelArtboard != null) {
        setState(() => _riveLoaded = true);
        debugPrint('Rive bone animations loaded: terry=${_terryArtboard != null}, nigel=${_nigelArtboard != null}');
      } else {
        debugPrint('No Rive artboards available, using PNG fallback');
      }
    } catch (e, stack) {
      debugPrint('Rive loading failed, using PNG fallback: $e');
      debugPrint('Stack: $stack');
      // Keep using PNG images as fallback
    }
  }

  /// Load custom bone animation skeletons from JSON
  Future<void> _loadSkeletons() async {
    try {
      // Load Terry skeleton
      _terrySkeleton = await loadSkeleton('assets/skeletons/terry_skeleton.json');
      debugPrint('Terry skeleton loaded: ${_terrySkeleton!.bones.length} bones, ${_terrySkeleton!.animations.length} animations');

      // Load Nigel skeleton
      _nigelSkeleton = await loadSkeleton('assets/skeletons/nigel_skeleton.json');
      debugPrint('Nigel skeleton loaded: ${_nigelSkeleton!.bones.length} bones, ${_nigelSkeleton!.animations.length} animations');

      setState(() => _skeletonsLoaded = true);
      debugPrint('Custom bone animation skeletons loaded successfully');
    } catch (e, stack) {
      debugPrint('Skeleton loading failed: $e');
      debugPrint('Stack: $stack');
      // PNG fallback still works
    }
  }

  /// Set character animation for bone system
  void _setBoneAnimation(String character, String animation) {
    setState(() {
      if (character == 'terry') {
        _terryAnimation = animation;
        _terryBoneKey.currentState?.playAnimation(animation);
      } else {
        _nigelAnimation = animation;
        _nigelBoneKey.currentState?.playAnimation(animation);
      }
    });
  }

  /// Handle commands from WFL server
  void _handleServerCommand(String command, Map<String, dynamic> payload) {
    switch (command) {
      case 'say':
        // Text-to-speech with lip-sync
        final text = payload['text'] as String?;
        final character = payload['character'] as String? ?? 'terry';
        if (text != null && text.isNotEmpty) {
          _sayWithLipSync(text, character);
        }
        break;

      case 'roast':
        // Vision AI roast from image, or quick reaction
        final image = payload['image'] as String?;
        final video = payload['video'] as String?;
        final character = payload['character'] as String? ?? 'terry';
        if (image != null) {
          _roastImage(image, character);
        } else if (video != null) {
          _playReaction(character, video);
        } else {
          _playReaction(character, character == 'terry' ? 'grunt' : 'groan');
        }
        break;

      case 'lip':
        final shape = payload['shape'] as String? ?? 'x';
        final character = payload['character'] as String? ?? 'terry';
        _setMouth(character, shape);
        break;

      case 'head':
        final angle = (payload['angle'] as num?)?.toDouble() ?? 0;
        final character = payload['character'] as String? ?? 'terry';
        setState(() {
          if (character == 'terry') {
            _terryEyeX = angle * 0.5; // Map angle to eye movement
          } else {
            _nigelEyeX = angle * 0.5;
          }
        });
        break;

      case 'pupil':
        final x = (payload['x'] as num?)?.toDouble() ?? 0;
        final y = (payload['y'] as num?)?.toDouble() ?? 0;
        setState(() {
          _terryEyeX = x;
          _terryEyeY = y;
          _nigelEyeX = x;
          _nigelEyeY = y;
        });
        break;

      case 'talk':
        final talking = payload['talking'] as bool? ?? false;
        _setTalking('terry', talking);
        _setTalking('nigel', talking);
        break;

      case 'warp':
        final path = payload['path'] as String?;
        if (path != null) {
          _loadWarpVideo(path);
        }
        break;

      case 'export':
        final filename = payload['filename'] as String?;
        if (filename != null && _isRecording) {
          _stopRecording();
        }
        break;

      case 'play':
        // Trigger default animation or track
        break;
    }
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  /// Start blink timer - random blinks every 2-5 seconds
  /// All other animation (breathing, sway, headBob, lean) handled by MirrorAnimationBuilder
  void _startBlinkTimer() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 2000 + 500), (_) {
      // Random delay between blinks (2-5 seconds)
      if (_random.nextDouble() > 0.4) return; // 60% chance to skip = varied timing

      // Start blink sequence with smooth transitions
      if (!mounted) return;
      setState(() {
        _terryBlinkState = 'half';
        _nigelBlinkState = 'half';
      });

      // Natural blink sequence (asymmetric timing)
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) setState(() {
          _terryBlinkState = 'closed';
          _nigelBlinkState = 'closed';
        });
      });
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) setState(() {
          _terryBlinkState = 'half';
          _nigelBlinkState = 'half';
        });
      });
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() {
          _terryBlinkState = 'open';
          _nigelBlinkState = 'open';
        });
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
        title: const Text('Recording Complete', style: TextStyle(color: Colors.white)),
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
          title: const Text('Disconnect YouTube?', style: TextStyle(color: Colors.white)),
          content: const Text('You\'ll need to sign in again to upload.', style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
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
    // Note: No AnimationController to dispose - MirrorAnimationBuilder manages its own
    _blinkTimer?.cancel();
    _wsClient.dispose();
    _voicePlayer.dispose();
    _porthole1?.dispose();
    _porthole2?.dispose();
    _porthole3?.dispose();
    _warpPlayer?.dispose();
    _flythroughVideo?.dispose();
    _lipSyncTimer?.cancel();
    _recordingTimer?.cancel();
    _showModeTimer?.cancel();
    _reactionTimer?.cancel();
    _subtitleTimer?.cancel();
    _dialogueTimer?.cancel();
    _audioRecorder.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    // Dispose Rive resources (StateMachineController doesn't have dispose in Rive 0.13.x)
    _terryStateMachine = null;
    _nigelStateMachine = null;
    _terryController?.dispose();
    _nigelController?.dispose();
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

    if (!_hasMicPermission) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live Mic ON - Hold MIC button to talk')),
    );
  }

  /// Start recording from mic (hold to talk)
  Future<void> _startLiveMicRecording() async {
    if (!_isLiveMicOn || _isRecordingMic) return;

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/live_recording.m4a';

    if (await _audioRecorder.hasPermission()) {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() => _isRecordingMic = true);
    }
  }

  /// Stop recording and process through roast pipeline
  Future<void> _stopLiveMicRecording() async {
    if (!_isRecordingMic) return;

    final path = await _audioRecorder.stop();
    setState(() => _isRecordingMic = false);

    if (path == null) return;

    // Show processing indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing your voice...')),
    );

    try {
      // 1. Transcribe audio (using Whisper API or similar)
      final transcription = await _autoRoast.transcribeAudio(File(path));
      _lastTranscription = transcription;

      if (transcription.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not hear you. Speak louder!')),
        );
        return;
      }

      // 2. Get roast response from Claude
      var roast = await _autoRoast.roastTranscription(transcription);

      // Cap at 15 words
      final words = roast.split(' ');
      if (words.length > 15) {
        roast = words.sublist(0, 15).join(' ');
      }

      // 3. Generate TTS with Terry (default for live mode)
      final audioBytes = await _autoRoast.generateSpeech(
        roast,
        _autoRoast.terryVoiceId,
        character: 'terry',
      );

      if (audioBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/live_roast.mp3');
        await audioFile.writeAsBytes(audioBytes);

        _lastRoastText = roast;
        _lastRoastAudio = audioFile.path;

        await _playWithLipSync(audioFile.path, 'terry', roast);
      }
    } catch (e) {
      debugPrint('Live roast error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Roast failed: $e')),
      );
    }
  }

  /// Initialize Rive state machine - use enum to prevent typos
  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, 'cockpit');
    if (controller != null) {
      artboard.addController(controller);
      _riveController = controller;
      // Use RiveInput enum - no typos, no frozen mouths (legacy)
      _buttonState = controller.findInput<double>(RiveInput.buttonState.name) as SMINumber?;
      // Note: String inputs don't exist in Rive - btnTarget removed
      _isTalking = controller.findInput<bool>(RiveInput.isTalking.name) as SMIBool?;
    }

    // Initialize Data Binding controllers (new API)
    _terryController = WFLCharacterController(
      characterName: 'terry',
      artboard: artboard,
    );
    _nigelController = WFLCharacterController(
      characterName: 'nigel',
      artboard: artboard,
    );

    // Log which API is being used
    if (_terryController?.hasDataBinding == true) {
      debugPrint('✓ Using Data Binding API for lip-sync');
    } else {
      debugPrint('⚠ Data Binding not found, using legacy PNG sprites');
    }
  }

  /// Set mouth shape using Data Binding or legacy sprites
  void _setMouth(String character, String phoneme) {
    final mouthShape = phoneme.toLowerCase();

    if (character == 'terry') {
      if (_terryController?.hasDataBinding == true) {
        _terryController!.setMouthFromPhoneme(phoneme);
      } else {
        setState(() => _terryMouth = mouthShape);
      }
      // Also update bone animator mouth
      if (_skeletonsLoaded) {
        _terryBoneKey.currentState?.setMouthShape(mouthShape);
      }
    } else if (character == 'nigel') {
      if (_nigelController?.hasDataBinding == true) {
        _nigelController!.setMouthFromPhoneme(phoneme);
      } else {
        setState(() => _nigelMouth = mouthShape);
      }
      // Also update bone animator mouth
      if (_skeletonsLoaded) {
        _nigelBoneKey.currentState?.setMouthShape(mouthShape);
      }
    }
  }

  /// Set talking state using Data Binding
  void _setTalking(String character, bool talking) {
    if (character == 'terry') {
      _terryController?.setTalking(talking);
    } else if (character == 'nigel') {
      _nigelController?.setTalking(talking);
    }

    // Also switch bone animation
    if (_skeletonsLoaded) {
      _setBoneAnimation(character, talking ? 'talking' : 'idle');
    }
  }

  /// Handle keyboard shortcuts: F1=thrusters, F2=warp, F3=shields, SHIFT+W=warp, SHIFT+F=focus
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isShift = HardwareKeyboard.instance.isShiftPressed;

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

    // SHIFT+I = image resizer
    if (event.logicalKey == LogicalKeyboardKey.keyI && isShift) {
      _openImageResizer();
      return;
    }

    // SHIFT+T = toggle flythrough mode (single video behind all portholes)
    if (event.logicalKey == LogicalKeyboardKey.keyT && isShift) {
      _toggleFlythroughMode();
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
      // SFX hotkeys 1-8
      case LogicalKeyboardKey.digit1:
      case LogicalKeyboardKey.numpad1:
        _playSfx('rimshot');
        break;
      case LogicalKeyboardKey.digit2:
      case LogicalKeyboardKey.numpad2:
        _playSfx('sad_trombone');
        break;
      case LogicalKeyboardKey.digit3:
      case LogicalKeyboardKey.numpad3:
        _playSfx('airhorn');
        break;
      case LogicalKeyboardKey.digit4:
      case LogicalKeyboardKey.numpad4:
        _playSfx('laugh_track');
        break;
      case LogicalKeyboardKey.digit5:
      case LogicalKeyboardKey.numpad5:
        _playSfx('drumroll');
        break;
      case LogicalKeyboardKey.digit6:
      case LogicalKeyboardKey.numpad6:
        _playSfx('whoosh');
        break;
      case LogicalKeyboardKey.digit7:
      case LogicalKeyboardKey.numpad7:
        _playSfx('ding');
        break;
      case LogicalKeyboardKey.digit8:
      case LogicalKeyboardKey.numpad8:
        _playSfx('buzzer');
        break;
      // Space = Play/Pause dialogue
      case LogicalKeyboardKey.space:
        _toggleDialogue();
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

  /// Open IMAGE RESIZER - Dragonbone to Illustrator specs
  void _openImageResizer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WFLImageResizer(),
      ),
    );
  }

  /// Toggle FLYTHROUGH MODE - single video behind all 3 portholes as masks
  /// Instead of 3 separate videos, ONE background video visible through all 3 portholes
  /// as if looking out at space/stars/nebula flying by
  Future<void> _toggleFlythroughMode() async {
    if (_flythroughMode) {
      // Exit flythrough mode
      _flythroughVideo?.pause();
      setState(() => _flythroughMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flythrough Mode OFF - 3 independent videos')),
      );
      return;
    }

    // Prompt for video path
    final pathController = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Row(
          children: [
            Icon(Icons.flight, color: Colors.cyan),
            SizedBox(width: 8),
            Text('FLYTHROUGH MODE', style: TextStyle(color: Colors.cyan)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Load a video that will play BEHIND all 3 portholes.\n'
              'The windows act as masks showing different parts of the same big video.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pathController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'C:\\Videos\\starfield.mp4',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pathController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text('ENGAGE'),
          ),
        ],
      ),
    );

    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }

    // Load the flythrough video
    _flythroughVideo?.dispose();
    _flythroughVideo = VideoPlayerController.file(file);

    try {
      await _flythroughVideo!.initialize();
      _flythroughVideo!.setLooping(true);
      _flythroughVideo!.setVolume(0); // Silent - just visuals
      await _flythroughVideo!.play();

      setState(() => _flythroughMode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flythrough Mode ON - SHIFT+T to exit'),
          backgroundColor: Colors.cyan,
        ),
      );
    } catch (e) {
      _flythroughVideo?.dispose();
      _flythroughVideo = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video load failed: $e')),
      );
    }
  }

  /// Toggle SHOW MODE - AI-powered auto-commentary
  /// Characters watch the videos and automatically generate roasts/commentary
  void _toggleShowMode() {
    if (_showMode) {
      // Turn off show mode
      _showModeTimer?.cancel();
      setState(() {
        _showMode = false;
        _isGeneratingCommentary = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Show Mode OFF')),
      );
      return;
    }

    // Check if any videos are loaded
    final hasVideos = (_porthole1?.value.isInitialized ?? false) ||
        (_porthole2?.value.isInitialized ?? false) ||
        (_porthole3?.value.isInitialized ?? false);

    if (!hasVideos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load videos first, then start Show Mode!')),
      );
      return;
    }

    // Start show mode
    setState(() => _showMode = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎬 SHOW MODE ON - Terry & Nigel are watching...'),
        backgroundColor: Colors.purple,
      ),
    );

    // Start the commentary loop - every 8-12 seconds, generate a new roast
    _runShowModeLoop();
  }

  /// Main show mode loop - captures frames, generates commentary, speaks
  Future<void> _runShowModeLoop() async {
    // Initial delay before first commentary
    await Future.delayed(const Duration(seconds: 2));

    _showModeTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_showMode || _isGeneratingCommentary) return;

      await _generateNextCommentary();
    });

    // Generate first commentary immediately
    await _generateNextCommentary();
  }

  /// Generate and speak the next piece of commentary
  Future<void> _generateNextCommentary() async {
    if (!_showMode || _isGeneratingCommentary) return;
    if (!WFLConfig.autoRoastEnabled) return;

    setState(() => _isGeneratingCommentary = true);

    try {
      // Pick which character speaks (alternates)
      final character = _currentSpeaker == 0 ? 'terry' : 'nigel';
      _currentSpeaker = (_currentSpeaker + 1) % 2;

      // Get a frame from one of the playing videos
      File? frameFile;
      VideoPlayerController? activePlayer;

      // Find an active video
      if (_porthole1?.value.isPlaying ?? false) {
        activePlayer = _porthole1;
      } else if (_porthole2?.value.isPlaying ?? false) {
        activePlayer = _porthole2;
      } else if (_porthole3?.value.isPlaying ?? false) {
        activePlayer = _porthole3;
      }

      // If no video playing, try to get one that's at least initialized
      if (activePlayer == null) {
        if (_porthole1?.value.isInitialized ?? false) activePlayer = _porthole1;
        else if (_porthole2?.value.isInitialized ?? false) activePlayer = _porthole2;
        else if (_porthole3?.value.isInitialized ?? false) activePlayer = _porthole3;
      }

      if (activePlayer == null) {
        setState(() => _isGeneratingCommentary = false);
        return;
      }

      // For now, use the video file directly for analysis
      // In production, you'd capture a frame using video_thumbnail or similar
      final videoPath = activePlayer.dataSource;
      final videoFile = File(videoPath);

      if (!await videoFile.exists()) {
        setState(() => _isGeneratingCommentary = false);
        return;
      }

      // Generate sarcastic commentary using Claude Vision
      var roast = await _autoRoast.describeSarcastic(videoFile);

      // Add some variety based on which character is speaking
      if (character == 'nigel') {
        // Nigel is more technical/nerdy
        if (!roast.contains('actually') && roast.length < 80) {
          roast = 'Actually, $roast';
        }
      }

      // Cap at 15 words
      final words = roast.split(' ');
      if (words.length > 15) {
        roast = words.sublist(0, 15).join(' ');
      }

      // Generate TTS
      final voiceId = character == 'nigel' ? _autoRoast.nigelVoiceId : _autoRoast.terryVoiceId;
      final audioBytes = await _autoRoast.generateSpeech(roast, voiceId, character: character);

      if (audioBytes.isNotEmpty && _showMode) {
        // Save and play
        final tempDir = Directory.systemTemp;
        final audioFile = File('${tempDir.path}/show_${character}_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await audioFile.writeAsBytes(audioBytes);

        await _playWithLipSync(audioFile.path, character, roast);

        // Wait for speech to finish before generating next
        await Future.delayed(Duration(milliseconds: roast.length * 80 + 1000));
      }
    } catch (e) {
      debugPrint('Show mode commentary error: $e');
    }

    if (mounted) {
      setState(() => _isGeneratingCommentary = false);
    }
  }

  /// Trigger a reaction animation for a character
  /// Reactions: neutral, laughing, shocked, facepalm, pointing, thinking
  void _triggerReaction(String character, String reaction, {Duration duration = const Duration(seconds: 2)}) {
    setState(() {
      if (character == 'terry') {
        _terryReaction = reaction;
      } else {
        _nigelReaction = reaction;
      }
    });

    // Reset to neutral after duration
    _reactionTimer?.cancel();
    _reactionTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _terryReaction = 'neutral';
          _nigelReaction = 'neutral';
        });
      }
    });
  }

  /// Get reaction-based animation modifiers
  Map<String, double> _getReactionModifiers(String character) {
    final reaction = character == 'terry' ? _terryReaction : _nigelReaction;

    switch (reaction) {
      case 'laughing':
        // Shake up and down rapidly
        return {
          'bobMultiplier': 3.0,
          'swayMultiplier': 1.5,
          'leanOffset': 0.02,
        };
      case 'shocked':
        // Lean back, wide
        return {
          'bobMultiplier': 0.5,
          'swayMultiplier': 0.2,
          'leanOffset': -0.03,
        };
      case 'facepalm':
        // Slump forward
        return {
          'bobMultiplier': 0.3,
          'swayMultiplier': 0.1,
          'leanOffset': 0.04,
        };
      case 'pointing':
        // Lean towards screen
        return {
          'bobMultiplier': 0.7,
          'swayMultiplier': 0.5,
          'leanOffset': 0.02,
        };
      case 'thinking':
        // Slow, contemplative
        return {
          'bobMultiplier': 0.4,
          'swayMultiplier': 0.3,
          'leanOffset': 0.01,
        };
      default: // neutral
        return {
          'bobMultiplier': 1.0,
          'swayMultiplier': 1.0,
          'leanOffset': 0.0,
        };
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
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'C:\\Videos\\clip.mp4',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, pathController.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('ENGAGE'),
            ),
          ],
        ),
      );

      if (path == null || path.isEmpty) return;

      final file = File(path);
      if (!await file.exists()) {
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

  /// Load warp video from path (for server commands)
  Future<void> _loadWarpVideo(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('WFL: Warp video not found: $path');
      return;
    }

    _warpPlayer?.dispose();
    _warpPlayer = VideoPlayerController.file(file);
    await _warpPlayer!.initialize();
    _warpPlayer!.setLooping(true);
    _warpPlayer!.setVolume(0);
    await _warpPlayer!.play();

    setState(() => _isWarp = true);
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
    // Note: String inputs removed - btnTarget not available
    _buttonState?.value = state.toDouble();
    setState(() {});
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
      await _voicePlayer.play(AssetSource(audioFile.replaceFirst('assets/', '')));
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
        title: Text('Load into Window $window', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: pathController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'C:\\Videos\\clip.mp4',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pathController.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) {
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

  Future<void> _loadPortholeVideo(int window, File file) async {
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
  Future<void> _onWindowContentAdded(int window, File file) async {
    // Add to queue
    _addToQueue(window, file);

    // React Mode OFF = just play clean, no drama
    if (!_reactMode) return;

    // Character reaction based on window
    final character = (window == 2) ? 'nigel' : 'terry';
    _playReaction(character, character == 'terry' ? 'grunt' : 'groan');

    // Auto-roast if API keys set
    if (WFLConfig.autoRoastEnabled) {
      final voiceId = window == 2 ? _autoRoast.nigelVoiceId : _autoRoast.terryVoiceId;

      try {
        var roast = await _autoRoast.describeSarcastic(file);

        // Cap at 15 words - TTS stutters, lips go stale otherwise
        final words = roast.split(' ');
        if (words.length > 15) {
          roast = words.sublist(0, 15).join(' ');
        }

        final audioBytes = await _autoRoast.generateSpeech(roast, voiceId, character: character);

        if (audioBytes.isNotEmpty) {
          // Save temp audio and play with lip-sync
          final tempDir = Directory.systemTemp;
          final audioFile = File('${tempDir.path}/roast_$window.mp3');
          await audioFile.writeAsBytes(audioBytes);

          // Save for focus mode
          _lastRoastText = roast;
          _lastRoastAudio = audioFile.path;

          await _playWithLipSync(audioFile.path, character, roast);
        }
      } catch (e) {
        debugPrint('Auto-roast error: $e');
      }
    }
  }

  void _playReaction(String character, String reaction) {
    // Quick mouth animation for grunt/groan
    final mouths = reaction == 'grunt' ? ['o', 'a', 'x'] : ['e', 'o', 'x'];

    int i = 0;
    _setTalking(character, true);
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (i >= mouths.length) {
        timer.cancel();
        _setTalking(character, false);
        return;
      }
      _setMouth(character, mouths[i]);
      i++;
    });
  }

  /// Play audio with lip-sync from phoneme cues
  Future<void> _playWithLipSync(String audioPath, String character, String text) async {
    // Generate basic cues from text (simplified)
    _currentCues = _generateMouthCues(text);
    _cueIndex = 0;

    // Start audio
    await _voicePlayer.play(DeviceFileSource(audioPath));
    _audioStartTime = DateTime.now();
    _setTalking(character, true);

    // Start lip-sync timer
    _lipSyncTimer?.cancel();
    _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_audioStartTime == null || _cueIndex >= _currentCues.length) {
        timer.cancel();
        _setMouth(character, 'x');
        _setTalking(character, false);
        return;
      }

      final elapsed = DateTime.now().difference(_audioStartTime!).inMilliseconds / 1000.0;
      final cue = _currentCues[_cueIndex];

      if (elapsed >= cue.time) {
        _setMouth(character, cue.mouth);
        _cueIndex++;
      }
    });
  }

  void _stopLipSync() {
    _lipSyncTimer?.cancel();
    _setMouth('terry', 'x');
    _setMouth('nigel', 'x');
    _setTalking('terry', false);
    _setTalking('nigel', false);
  }

  /// Say text with TTS and lip-sync (for server commands)
  Future<void> _sayWithLipSync(String text, String character) async {
    if (!WFLConfig.autoRoastEnabled) {
      debugPrint('WFL: Auto-roast not enabled (missing API keys)');
      _playReaction(character, character == 'terry' ? 'grunt' : 'groan');
      return;
    }

    try {
      // Get voice ID for character
      final voiceId = character == 'nigel' ? _autoRoast.nigelVoiceId : _autoRoast.terryVoiceId;

      // Generate TTS audio (PCM format)
      final pcmBytes = await _autoRoast.generateSpeech(text, voiceId, character: character);

      if (pcmBytes.isNotEmpty) {
        // Convert PCM to WAV by adding header
        final wavBytes = _createWavFromPcm(pcmBytes, 44100, 1, 16);

        // Save as WAV file
        final tempDir = Directory.systemTemp;
        final audioFile = File('${tempDir.path}/say_${character}_${DateTime.now().millisecondsSinceEpoch}.wav');
        await audioFile.writeAsBytes(wavBytes);

        // Notify server first
        _wsClient.sendStatus('speaking', {'character': character, 'text': text});

        // Start lip-sync animation
        _currentCues = _generateMouthCues(text);
        _cueIndex = 0;
        _audioStartTime = DateTime.now();
        _setTalking(character, true);

        // Start lip-sync timer
        _lipSyncTimer?.cancel();
        _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
          if (_audioStartTime == null || _cueIndex >= _currentCues.length) {
            timer.cancel();
            _setMouth(character, 'x');
            _setTalking(character, false);
            return;
          }
          final elapsed = DateTime.now().difference(_audioStartTime!).inMilliseconds / 1000.0;
          if (_cueIndex < _currentCues.length) {
            final cue = _currentCues[_cueIndex];
            if (elapsed >= cue.time) {
              _setMouth(character, cue.mouth);
              _cueIndex++;
            }
          }
        });

        // Play WAV using Windows PowerShell SoundPlayer
        await Process.run('powershell', [
          '-Command',
          '(New-Object System.Media.SoundPlayer "${audioFile.path}").PlaySync()'
        ]);

        // Stop lip-sync after audio completes
        _lipSyncTimer?.cancel();
        _setMouth(character, 'x');
        _setTalking(character, false);
      }
    } catch (e) {
      debugPrint('WFL say error: $e');
      _playReaction(character, character == 'terry' ? 'grunt' : 'groan');
    }
  }

  /// Create WAV file from raw PCM data
  List<int> _createWavFromPcm(List<int> pcmData, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = <int>[
      // RIFF header
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      fileSize & 0xff, (fileSize >> 8) & 0xff, (fileSize >> 16) & 0xff, (fileSize >> 24) & 0xff,
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      // fmt chunk
      0x66, 0x6d, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // chunk size
      1, 0, // audio format (PCM)
      channels & 0xff, (channels >> 8) & 0xff,
      sampleRate & 0xff, (sampleRate >> 8) & 0xff, (sampleRate >> 16) & 0xff, (sampleRate >> 24) & 0xff,
      byteRate & 0xff, (byteRate >> 8) & 0xff, (byteRate >> 16) & 0xff, (byteRate >> 24) & 0xff,
      blockAlign & 0xff, (blockAlign >> 8) & 0xff,
      bitsPerSample & 0xff, (bitsPerSample >> 8) & 0xff,
      // data chunk
      0x64, 0x61, 0x74, 0x61, // "data"
      dataSize & 0xff, (dataSize >> 8) & 0xff, (dataSize >> 16) & 0xff, (dataSize >> 24) & 0xff,
    ];

    return [...header, ...pcmData];
  }

  /// Roast an image with Vision AI + TTS (for server commands)
  Future<void> _roastImage(String imagePath, String character) async {
    if (!WFLConfig.autoRoastEnabled) {
      debugPrint('WFL: Auto-roast not enabled (missing API keys)');
      _playReaction(character, character == 'terry' ? 'grunt' : 'groan');
      return;
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      debugPrint('WFL: Image not found: $imagePath');
      _playReaction(character, character == 'terry' ? 'grunt' : 'groan');
      return;
    }

    try {
      // Quick reaction while AI processes
      _playReaction(character, character == 'terry' ? 'grunt' : 'groan');

      // Get sarcastic description from Vision AI
      var roast = await _autoRoast.describeSarcastic(file);

      // Cap at 15 words
      final words = roast.split(' ');
      if (words.length > 15) {
        roast = words.sublist(0, 15).join(' ');
      }

      debugPrint('WFL Roast: $roast');

      // Generate TTS
      final voiceId = character == 'nigel' ? _autoRoast.nigelVoiceId : _autoRoast.terryVoiceId;
      final audioBytes = await _autoRoast.generateSpeech(roast, voiceId, character: character);

      if (audioBytes.isNotEmpty) {
        // Save temp audio
        final tempDir = Directory.systemTemp;
        final audioFile = File('${tempDir.path}/roast_${character}_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await audioFile.writeAsBytes(audioBytes);

        // Play with lip-sync
        await _playWithLipSync(audioFile.path, character, roast);

        // Notify server
        _wsClient.sendStatus('roasted', {'character': character, 'roast': roast});
      }
    } catch (e) {
      debugPrint('WFL roast error: $e');
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

      if ('aáà'.contains(char)) mouth = 'a';
      else if ('eéè'.contains(char)) mouth = 'e';
      else if ('iíì'.contains(char)) mouth = 'i';
      else if ('oóò'.contains(char)) mouth = 'o';
      else if ('uúù'.contains(char)) mouth = 'u';
      else if ('fv'.contains(char)) mouth = 'f';
      else if ('lrw'.contains(char)) mouth = 'l';
      else if ('mbp'.contains(char)) mouth = 'm';
      else if (char == ' ') mouth = 'x';

      if (mouth != 'x' || (cues.isNotEmpty && cues.last.mouth != 'x')) {
        cues.add(MouthCue(time, mouth));
      }
      time += avgCharDuration;
    }

    return cues;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: false,  // Focus requested in initState after layout
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
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
                        // Cockpit
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRect(
                                child: GestureDetector(
                                  onTapDown: _onCockpitTap,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // WARP MODE: Full-screen video behind everything
                                      if (_isWarp && _warpPlayer != null && _warpPlayer!.value.isInitialized)
                                        Positioned.fill(
                                          child: ColorFiltered(
                                            colorFilter: ColorFilter.mode(
                                              Colors.black.withOpacity(0.3),
                                              BlendMode.darken,
                                            ),
                                            child: VideoPlayer(_warpPlayer!),
                                          ),
                                        ),

                                      // Normal background (dimmed in warp)
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: _isWarp ? 0.0 : 1.0,
                                          child: _spaceship,
                                        ),
                                      ),

                                      // Ship overlay (always on top) - IgnorePointer so characters can be dragged
                                      Positioned.fill(child: IgnorePointer(child: _buttonsPanel)),
                                      _buildPortholes(),
                                      // Characters BEHIND the table (rendered first, table on top)
                                      // Each component (body, eyes, mouth) has its own resize box
                                      // Terry components - Positioned.fill so inner Stack positions work
                                      Positioned.fill(
                                        child: _buildCharacterWithComponents('terry', _terryBody, _terryMouth),
                                      ),
                                      // Nigel components - Positioned.fill so inner Stack positions work
                                      Positioned.fill(
                                        child: _buildCharacterWithComponents('nigel', _nigelBody, _nigelMouth),
                                      ),
                                      // Table IN FRONT of characters (talk show desk) - IgnorePointer for character drag
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(child: _table),
                                      ),
                                      Positioned(
                                        bottom: 10,
                                        right: 10,
                                        child: _buildHotkeyHints(),
                                      ),

                                      // WARP HUD - green text overlay
                                      if (_isWarp) _buildWarpHUD(),

                                      // Subtitle bar at bottom
                                      _buildSubtitleBar(),

                                      // SFX trigger buttons panel (top-right)
                                      _buildSfxPanel(),

                                      // Play/Pause dialogue button (bottom-right)
                                      _buildPlayPauseButton(),
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

                  // Queue panel (right)
                  _buildQueuePanel(),
                ],
              ),
            ),
          ],
        ),
      ),
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

          const SizedBox(width: 16),

          // Flythrough Mode toggle
          GestureDetector(
            onTap: _toggleFlythroughMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _flythroughMode ? Colors.cyan : const Color(0xFF3a3a4e),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _flythroughMode ? Colors.cyan.shade300 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flight,
                    color: _flythroughMode ? Colors.white : Colors.cyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _flythroughMode ? 'FLYTHROUGH' : 'FLY',
                    style: TextStyle(
                      color: _flythroughMode ? Colors.white : Colors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SHOW MODE toggle - AI auto-commentary
          GestureDetector(
            onTap: _toggleShowMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _showMode ? Colors.purple : const Color(0xFF3a3a4e),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showMode ? Colors.purple.shade300 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showMode ? Icons.auto_awesome : Icons.movie_creation,
                    color: _showMode ? Colors.white : Colors.purple,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showMode
                        ? (_isGeneratingCommentary ? 'THINKING...' : 'SHOW ON')
                        : 'SHOW',
                    style: TextStyle(
                      color: _showMode ? Colors.white : Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

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
                    : (_isLiveMicOn ? Colors.orange.shade800 : const Color(0xFF3a3a4e)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRecordingMic ? Colors.orange.shade300 : Colors.transparent,
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
                    _isRecordingMic ? 'LISTENING...' : (_isLiveMicOn ? 'MIC ON' : 'LIVE'),
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
                  color: _isRecording ? Colors.red.shade300 : Colors.transparent,
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
              color: WFLUploader.isYouTubeConnected ? Colors.green : Colors.grey,
            ),
            label: Text(
              WFLUploader.isYouTubeConnected ? 'YouTube ✓' : 'Connect YouTube',
              style: TextStyle(
                color: WFLUploader.isYouTubeConnected ? Colors.green : Colors.white70,
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
                const Text('Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_roastQueue.length}', style: const TextStyle(color: Colors.grey)),
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
                      final isPlaying = _isPlayingQueue && index == _currentQueueIndex;
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
                      backgroundColor: _isPlayingQueue ? Colors.red : Colors.green,
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
        color: isPlaying ? Colors.green.withOpacity(0.3) : const Color(0xFF2a2a3e),
        borderRadius: BorderRadius.circular(8),
        border: isPlaying ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: item.thumbnail != null
              ? Image.memory(item.thumbnail!, width: 50, height: 50, fit: BoxFit.cover)
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
      await _loadPortholeVideo(item.window, File(item.path));

      // React if enabled
      if (_reactMode) {
        await _onWindowContentAdded(item.window, File(item.path));
      }

      // Wait for roast to finish (or 5 seconds if no react)
      await Future.delayed(Duration(seconds: _reactMode ? 8 : 5));
    }

    setState(() => _isPlayingQueue = false);
  }

  /// Add to queue when dropping video
  void _addToQueue(int window, File file, {Uint8List? thumbnail}) {
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
      'queue': _roastQueue.map((q) => {'path': q.path, 'window': q.window}).toList(),
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
            _volume < 0.3 ? Icons.volume_mute : (_volume < 0.7 ? Icons.volume_down : Icons.volume_up),
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
        title: const Text('Export Quality', style: TextStyle(color: Colors.white)),
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

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: Text('Exporting ${preset.name}...', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('${preset.resolution} @ ${preset.fps}fps', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      // Use temp directory - antivirus won't lock it, cleans up automatically
      final tempDir = await getTemporaryDirectory();
      final framesPath = '${tempDir.path}/wfl_frames';
      final outputPath = '${tempDir.path}/output_${preset.name.toLowerCase()}.mp4';

      // Clean frames folder first - crashes if leftover from last render
      final framesDir = Directory(framesPath);
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      await framesDir.create();

      // FFmpeg export with preset
      final result = await Process.run('ffmpeg', [
        '-y',
        '-framerate', '${preset.fps}',
        '-i', '$framesPath/%04d.png',
        '-vcodec', 'libx264',
        '-s', preset.resolution,
        '-pix_fmt', 'yuv420p',
        '-crf', '${preset.crf}',
        '-af', 'loudnorm',
        outputPath,
      ]);

      Navigator.pop(context);

      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported: $outputPath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${result.stderr}')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FFmpeg not found. Install FFmpeg first.')),
      );
    }
  }

  Widget _exportOption(BuildContext ctx, ExportPreset preset) {
    return ListTile(
      title: Text(preset.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text('${preset.resolution} • ${preset.description}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
            Text('Posting Roast #${WFLUploader.roastNumber}', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Rendering → YouTube → Share Sheet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      // Use temp directory - antivirus won't lock it
      final tempDir = await getTemporaryDirectory();
      final framesPath = '${tempDir.path}/wfl_frames';
      final outputPath = '${tempDir.path}/output_roast_${WFLUploader.roastNumber}.mp4';

      // 1. Export video (YouTube preset - 1080x720)
      await Process.run('ffmpeg', [
        '-y',
        '-framerate', '30',
        '-i', '$framesPath/%04d.png',
        '-vcodec', 'libx264',
        '-s', '1080x720',
        '-pix_fmt', 'yuv420p',
        '-crf', '18',
        '-af', 'loudnorm',
        outputPath,
      ]);

      final videoFile = File(outputPath);
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
                SelectableText(youtubeUrl, style: const TextStyle(color: Colors.blue)),
                const SizedBox(height: 8),
              ],
              const Text('Share sheet opened for TikTok/Reels/Shorts', style: TextStyle(color: Colors.grey)),
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
            color: Colors.orange.shade900.withOpacity(0.9),
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
          const Text('F1 Thrusters', style: TextStyle(fontSize: 10, color: Colors.white70)),
          const Text('F2 Warp', style: TextStyle(fontSize: 10, color: Colors.white70)),
          const Text('F3 Shields', style: TextStyle(fontSize: 10, color: Colors.white70)),
          if (!_isWarp) const Text('SHIFT+W Warp Mode', style: TextStyle(fontSize: 10, color: Colors.green)),
          Text(
            _flythroughMode ? 'SHIFT+T Exit Flythrough' : 'SHIFT+T Flythrough',
            style: TextStyle(fontSize: 10, color: _flythroughMode ? Colors.cyan : Colors.cyan.shade300),
          ),
          const Text('SHIFT+F Focus Mode', style: TextStyle(fontSize: 10, color: Colors.cyan)),
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
                color: Colors.green.withOpacity(0.3),
              ),
            ),

            // Bottom HUD bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
    // In flythrough mode, show clipped regions of single background video
    if (_flythroughMode && _flythroughVideo != null && _flythroughVideo!.value.isInitialized) {
      return Stack(
        children: [
          // Porthole 1 - Left (shows left portion of video)
          Positioned(
            left: 100,
            top: 80,
            child: _buildFlythroughPorthole(1, const Alignment(-0.7, 0)),
          ),
          // Porthole 2 - Center (shows center portion of video)
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            child: Center(child: _buildFlythroughPorthole(2, Alignment.center)),
          ),
          // Porthole 3 - Right (shows right portion of video)
          Positioned(
            right: 100,
            top: 80,
            child: _buildFlythroughPorthole(3, const Alignment(0.7, 0)),
          ),
        ],
      );
    }

    // Normal mode - 3 independent videos
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

  /// Build a flythrough porthole - clips a region of the shared background video
  Widget _buildFlythroughPorthole(int index, Alignment alignment) {
    const size = 150.0;
    final videoWidth = _flythroughVideo!.value.size.width;
    final videoHeight = _flythroughVideo!.value.size.height;
    final aspectRatio = videoWidth / videoHeight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyan.shade700, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipOval(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            // Make video large enough to clip different regions
            width: size * 3,
            height: size * 3 / aspectRatio,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: alignment,
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(_flythroughVideo!),
              ),
            ),
          ),
        ),
      ),
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
              color: Colors.black.withOpacity(0.5),
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

  /// Build character using Rive bone animation (preferred) or transparent PNG fallback
  /// Rive provides smooth bone-based animations, PNG is used as fallback
  /// Build character with separate resizable components (body, eyes, mouth)
  /// Returns a Stack containing all components as individually positioned widgets
  /// Uses simple_animations MirrorAnimationBuilder for organic idle motion
  Widget _buildCharacterWithComponents(String name, Image body, String mouth) {
    final config = _characterConfig[name] ?? _characterConfig['terry']!;
    final blinkState = name == 'terry' ? _terryBlinkState : _nigelBlinkState;

    // Get component transforms for this character
    final bodyScale = name == 'terry' ? _terryBodyScale : _nigelBodyScale;
    final bodyOffset = name == 'terry' ? _terryBodyOffset : _nigelBodyOffset;
    final eyesScale = name == 'terry' ? _terryEyesScale : _nigelEyesScale;
    final eyesOffset = name == 'terry' ? _terryEyesOffset : _nigelEyesOffset;
    final mouthScale = name == 'terry' ? _terryMouthScale : _nigelMouthScale;
    final mouthOffset = name == 'terry' ? _terryMouthOffset : _nigelMouthOffset;

    // Select the appropriate MovieTween for this character
    final idleTween = name == 'terry' ? terryIdleTween : nigelIdleTween;

    // Base positions - characters sit behind table (table is at bottom: 0)
    final baseLeft = name == 'terry' ? 50.0 : null;
    final baseRight = name == 'terry' ? null : 50.0;
    const baseBottom = 120.0;  // Position characters above table baseline

    // Component colors for resize boxes
    final bodyColor = name == 'terry' ? Colors.cyan : Colors.lightGreen;
    final eyesColor = name == 'terry' ? Colors.blue : Colors.teal;
    final mouthColor = name == 'terry' ? Colors.orange : Colors.amber;

    // WRAP ENTIRE CHARACTER IN MIRRORANIMATIONBUILDER
    // This gives us fluid bone-like movement: breathing, swaying, head bobbing
    // MirrorAnimationBuilder automatically loops forward<->backward for seamless idle
    return MirrorAnimationBuilder<Movie>(
      tween: idleTween,
      duration: idleTween.duration,
      builder: (context, value, child) {
        // Extract animation values from MovieTween
        final breathY = value.get<double>('breathY');
        final eyeX = value.get<double>('eyeX');
        final eyeY = value.get<double>('eyeY');
        final headBob = value.get<double>('headBob');
        final sway = value.get<double>('sway');
        final lean = value.get<double>('lean');

        return Transform(
          transform: Matrix4.identity()
            ..translate(sway, breathY + headBob)
            ..rotateZ(lean * 0.01),
          alignment: Alignment.bottomCenter,
          child: _buildCharacterStack(
            name: name,
            config: config,
            blinkState: blinkState,
            eyeX: eyeX,
            eyeY: eyeY,
            headBob: headBob,
            bodyScale: bodyScale,
            bodyOffset: bodyOffset,
            eyesScale: eyesScale,
            eyesOffset: eyesOffset,
            mouthScale: mouthScale,
            mouthOffset: mouthOffset,
            baseLeft: baseLeft,
            baseRight: baseRight,
            baseBottom: baseBottom,
            bodyColor: bodyColor,
            eyesColor: eyesColor,
            mouthColor: mouthColor,
            body: body,
            mouth: mouth,
          ),
        );
      },
    );
  }

  /// Helper: Build the character component stack (extracted for MirrorAnimationBuilder)
  Widget _buildCharacterStack({
    required String name,
    required Map<String, dynamic> config,
    required String blinkState,
    required double eyeX,
    required double eyeY,
    required double headBob,
    required double bodyScale,
    required Offset bodyOffset,
    required double eyesScale,
    required Offset eyesOffset,
    required double mouthScale,
    required Offset mouthOffset,
    required double? baseLeft,
    required double? baseRight,
    required double baseBottom,
    required Color bodyColor,
    required Color eyesColor,
    required Color mouthColor,
    required Image body,
    required String mouth,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // BODY - main character sprite
        Positioned(
          left: baseLeft != null ? baseLeft + bodyOffset.dx : null,
          right: baseRight != null ? baseRight - bodyOffset.dx : null,
          bottom: baseBottom + bodyOffset.dy,
          child: _buildResizableComponent(
            label: '${name.toUpperCase()} BODY',
            color: bodyColor,
            scale: bodyScale,
            onScaleUpdate: (scale) {
              setState(() {
                if (name == 'terry') {
                  _terryBodyScale = scale.clamp(_minScale, _maxScale);
                } else {
                  _nigelBodyScale = scale.clamp(_minScale, _maxScale);
                }
              });
            },
            onDragUpdate: (delta) {
              setState(() {
                if (name == 'terry') {
                  _terryBodyOffset += delta;
                } else {
                  _nigelBodyOffset += Offset(-delta.dx, delta.dy);
                }
              });
            },
            onReset: () {
              setState(() {
                if (name == 'terry') {
                  _terryBodyScale = _defaultScale;
                  _terryBodyOffset = Offset.zero;
                } else {
                  _nigelBodyScale = _defaultScale;
                  _nigelBodyOffset = Offset.zero;
                }
              });
            },
            child: SizedBox(
              // Use proper aspect ratio: Nigel is landscape (1.83:1), Terry is portrait
              width: config['bodyAspectRatio'] != null ? 400 : 300,
              height: config['bodyAspectRatio'] != null ? (400 / (config['bodyAspectRatio'] as double)).round().toDouble() : 400,
              child: body,
            ),
          ),
        ),

        // EYES - if character has separate eye sprites
        if (config['hasEyes'] == true)
          Builder(builder: (context) {
            // Calculate container height based on aspect ratio
            final containerHeight = config['bodyAspectRatio'] != null
                ? (400 / (config['bodyAspectRatio'] as double)).round().toDouble()
                : 400.0;
            return Positioned(
              left: baseLeft != null
                  ? baseLeft + bodyOffset.dx + (config['eyesX'] as double) + eyeX + eyesOffset.dx
                  : null,
              right: baseRight != null
                  ? baseRight - bodyOffset.dx - (config['eyesX'] as double) - eyeX - eyesOffset.dx
                  : null,
              bottom: baseBottom + bodyOffset.dy + (containerHeight - (config['eyesY'] as double) - eyeY) + eyesOffset.dy,
            child: _buildResizableComponent(
              label: '${name.toUpperCase()} EYES',
              color: eyesColor,
              scale: eyesScale,
              onScaleUpdate: (scale) {
                setState(() {
                  if (name == 'terry') {
                    _terryEyesScale = scale.clamp(_minScale, _maxScale);
                  } else {
                    _nigelEyesScale = scale.clamp(_minScale, _maxScale);
                  }
                });
              },
              onDragUpdate: (delta) {
                setState(() {
                  if (name == 'terry') {
                    _terryEyesOffset += delta;
                  } else {
                    _nigelEyesOffset += Offset(-delta.dx, delta.dy);
                  }
                });
              },
              onReset: () {
                setState(() {
                  if (name == 'terry') {
                    _terryEyesScale = _defaultScale;
                    _terryEyesOffset = Offset.zero;
                  } else {
                    _nigelEyesScale = _defaultScale;
                    _nigelEyesOffset = Offset.zero;
                  }
                });
              },
              child: Image.asset(
                'assets/characters/$name/eyes/eyes_$blinkState.png',
                width: config['eyesWidth'] as double,  // Scale applied by Transform.scale
                height: config['eyesHeight'] as double,
                errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 40,
                  color: eyesColor.withOpacity(0.3),
                  child: const Center(child: Text('EYES', style: TextStyle(color: Colors.white, fontSize: 10))),
                ),
              ),
            ),
            ); // Close Positioned
          }), // Close Builder

        // MOUTH - lip sync shapes
        // Check if mouth is full-frame (already positioned in image) or cropped (needs positioning)
        if (config['mouthFullFrame'] == true)
          // FULL-FRAME MOUTH (Nigel) - overlay at same position as body, no manual positioning needed
          Positioned(
            left: baseLeft != null ? baseLeft + bodyOffset.dx : null,
            right: baseRight != null ? baseRight - bodyOffset.dx : null,
            bottom: baseBottom + bodyOffset.dy,
            child: IgnorePointer(
              child: SizedBox(
                // Match body container size for proper overlay
                width: config['bodyAspectRatio'] != null ? 400 : 300,
                height: config['bodyAspectRatio'] != null ? (400 / (config['bodyAspectRatio'] as double)).round().toDouble() : 400,
                child: Image.asset(
                  'assets/characters/$name/mouth_shapes/$mouth.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          )
        else
          // CROPPED MOUTH (Terry) - needs manual positioning
          Positioned(
            left: baseLeft != null
                ? baseLeft + bodyOffset.dx + (config['mouthX'] as double) + mouthOffset.dx
                : null,
            right: baseRight != null
                ? baseRight - bodyOffset.dx - (config['mouthX'] as double) - mouthOffset.dx
                : null,
            bottom: baseBottom + bodyOffset.dy + (400 - (config['mouthY'] as double)) + mouthOffset.dy,
            child: _buildResizableComponent(
              label: '${name.toUpperCase()} MOUTH',
              color: mouthColor,
              scale: mouthScale,
              onScaleUpdate: (scale) {
                setState(() {
                  if (name == 'terry') {
                    _terryMouthScale = scale.clamp(_minScale, _maxScale);
                  } else {
                    _nigelMouthScale = scale.clamp(_minScale, _maxScale);
                  }
                });
              },
              onDragUpdate: (delta) {
                setState(() {
                  if (name == 'terry') {
                    _terryMouthOffset += delta;
                  } else {
                    _nigelMouthOffset += Offset(-delta.dx, delta.dy);
                  }
                });
              },
              onReset: () {
                setState(() {
                  if (name == 'terry') {
                    _terryMouthScale = _defaultScale;
                    _terryMouthOffset = Offset.zero;
                  } else {
                    _nigelMouthScale = _defaultScale;
                    _nigelMouthOffset = Offset.zero;
                  }
                });
              },
              child: Image.asset(
                'assets/characters/$name/mouth_shapes/$mouth.png',
                width: config['mouthWidth'] as double,  // Scale applied by Transform.scale
                height: config['mouthHeight'] as double,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 40,
                  color: mouthColor.withOpacity(0.3),
                  child: const Center(child: Text('MOUTH', style: TextStyle(color: Colors.white, fontSize: 10))),
                ),
              ),
            ),
          ),
      ],
    ); // Close Stack
  }

  /// Build a resizable component with visible handles
  Widget _buildResizableComponent({
    required String label,
    required Color color,
    required double scale,
    required void Function(double) onScaleUpdate,
    required void Function(Offset) onDragUpdate,
    required VoidCallback onReset,
    required Widget child,
  }) {
    const handleSize = 14.0;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
          onScaleUpdate(scale + delta);
        }
      },
      // APPLY SCALE via Transform.scale - this is what makes resize actually work!
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main content with border
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) => onDragUpdate(details.delta),
              onDoubleTap: onReset,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: color.withOpacity(0.7), width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: child,
              ),
            ),
          ),

          // Label tag
          Positioned(
            top: -18,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Text(
                '$label ${(scale * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Corner resize handles
          // Top-left
          Positioned(
            top: -handleSize / 2,
            left: -handleSize / 2,
            child: _buildHandle(
              cursor: SystemMouseCursors.resizeUpLeft,
              color: color,
              size: handleSize,
              onDrag: (delta) => onScaleUpdate(scale + (-delta.dx + -delta.dy) * 0.005),
            ),
          ),
          // Top-right
          Positioned(
            top: -handleSize / 2,
            right: -handleSize / 2,
            child: _buildHandle(
              cursor: SystemMouseCursors.resizeUpRight,
              color: color,
              size: handleSize,
              onDrag: (delta) => onScaleUpdate(scale + (delta.dx + -delta.dy) * 0.005),
            ),
          ),
          // Bottom-left
          Positioned(
            bottom: -handleSize / 2,
            left: -handleSize / 2,
            child: _buildHandle(
              cursor: SystemMouseCursors.resizeDownLeft,
              color: color,
              size: handleSize,
              onDrag: (delta) => onScaleUpdate(scale + (-delta.dx + delta.dy) * 0.005),
            ),
          ),
          // Bottom-right
          Positioned(
            bottom: -handleSize / 2,
            right: -handleSize / 2,
            child: _buildHandle(
              cursor: SystemMouseCursors.resizeDownRight,
              color: color,
              size: handleSize,
              onDrag: (delta) => onScaleUpdate(scale + (delta.dx + delta.dy) * 0.005),
            ),
          ),
        ],
      ), // Close Stack
      ), // Close Transform.scale
    ); // Close Listener
  }

  /// Build a single resize handle
  Widget _buildHandle({
    required MouseCursor cursor,
    required Color color,
    required double size,
    required void Function(Offset) onDrag,
  }) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacter(String name, Image body, String mouth) {
    final artboard = name == 'terry' ? _terryArtboard : _nigelArtboard;
    final skeleton = name == 'terry' ? _terrySkeleton : _nigelSkeleton;

    // Priority 1: Rive bone animation (if .riv file has valid artboards)
    if (_riveLoaded && artboard != null) {
      return _buildRiveCharacter(name, artboard);
    }

    // Priority 2: Custom bone animation system (if skeletons loaded)
    if (_skeletonsLoaded && skeleton != null) {
      return _buildBoneCharacter(name, skeleton);
    }

    // Priority 3: PNG layer fallback
    return _buildPngCharacter(name, body, mouth);
  }

  /// Build character using Rive bone animation
  Widget _buildRiveCharacter(String name, Artboard artboard) {
    return SizedBox(
      width: 300,
      height: 400,
      child: Rive(
        artboard: artboard,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }

  /// Build character using custom bone animation system
  Widget _buildBoneCharacter(String name, Skeleton skeleton) {
    final animation = name == 'terry' ? _terryAnimation : _nigelAnimation;
    final key = name == 'terry' ? _terryBoneKey : _nigelBoneKey;
    final basePath = 'assets/characters/$name';

    return SizedBox(
      width: skeleton.canvasSize.width * 0.6, // Scale to fit character panel
      height: skeleton.canvasSize.height * 0.6,
      child: BoneAnimatorWidget(
        key: key,
        skeleton: skeleton,
        currentAnimation: animation,
        assetBasePath: basePath,
        scale: 0.6,
        showBones: true, // Debug: visualize bone structure
      ),
    );
  }

  /// Build character using transparent PNG images (fallback)
  /// Uses simple_animations MirrorAnimationBuilder for organic idle motion
  Widget _buildPngCharacter(String name, Image body, String mouth) {
    final config = _characterConfig[name] ?? _characterConfig['terry']!;
    final blinkState = name == 'terry' ? _terryBlinkState : _nigelBlinkState;

    // Select the appropriate MovieTween for this character
    final idleTween = name == 'terry' ? terryIdleTween : nigelIdleTween;

    // Apply reaction modifiers
    final reactionMods = _getReactionModifiers(name);
    final bobMod = reactionMods['bobMultiplier'] ?? 1.0;
    final swayMod = reactionMods['swayMultiplier'] ?? 1.0;
    final leanOffset = reactionMods['leanOffset'] ?? 0.0;

    return MirrorAnimationBuilder<Movie>(
      tween: idleTween,
      duration: idleTween.duration,
      builder: (context, value, child) {
        // Extract animation values from MovieTween
        final breathY = value.get<double>('breathY');
        final eyeX = value.get<double>('eyeX');
        final eyeY = value.get<double>('eyeY');
        final headBob = value.get<double>('headBob');
        final sway = value.get<double>('sway');
        final lean = value.get<double>('lean');

        return Transform(
          // Apply multiple transforms: sway, lean, and bob (modified by reactions)
          transform: Matrix4.identity()
            ..translate(sway * swayMod, breathY + headBob * bobMod)
            ..rotateZ((lean * 0.01) + leanOffset),
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 300,
            height: 400,
            child: Stack(
              children: [
                // Use transparent full-body character image
                Positioned.fill(
                  child: body,
                ),

                // Eyes layer (if character has separate eye sprites)
                if (config['hasEyes'] == true)
                  Positioned(
                    left: (config['eyesX'] as double) + eyeX,
                    top: (config['eyesY'] as double) + eyeY + headBob * 0.3,
                    child: Image.asset(
                      'assets/characters/$name/eyes/eyes_$blinkState.png',
                      width: config['eyesWidth'] as double,
                      height: config['eyesHeight'] as double,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                // Mouth layer (swapped based on current phoneme)
                Positioned(
                  left: config['mouthX'] as double,
                  top: (config['mouthY'] as double) + headBob * 0.3,
                  child: Image.asset(
                    'assets/characters/$name/mouth_shapes/$mouth.png',
                    width: config['mouthWidth'] as double,
                    height: config['mouthHeight'] as double,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== SUBTITLE SYSTEM ====================

  /// Show a subtitle with speaker name and text
  void showSubtitle(String speaker, String text, {Duration? duration}) {
    _subtitleTimer?.cancel();
    setState(() {
      _subtitleSpeaker = speaker;
      _subtitleText = text;
      _subtitleVisible = true;
    });

    // Auto-hide after duration (default: estimate based on text length)
    final displayDuration = duration ?? Duration(
      milliseconds: 2000 + (text.length * 50), // ~50ms per character
    );

    _subtitleTimer = Timer(displayDuration, () {
      hideSubtitle();
    });
  }

  /// Hide the current subtitle with fade out
  void hideSubtitle() {
    setState(() {
      _subtitleVisible = false;
    });
  }

  /// Clear subtitle immediately (no fade)
  void clearSubtitle() {
    _subtitleTimer?.cancel();
    setState(() {
      _subtitleVisible = false;
      _subtitleText = '';
      _subtitleSpeaker = '';
    });
  }

  /// Build the subtitle bar widget
  Widget _buildSubtitleBar() {
    // Speaker colors: Terry = cyan/blue, Nigel = green, Narrator = white
    Color speakerColor;
    String displayName;

    switch (_subtitleSpeaker.toLowerCase()) {
      case 'terry':
        speakerColor = Colors.cyan;
        displayName = 'TERRY';
        break;
      case 'nigel':
        speakerColor = Colors.lightGreen;
        displayName = 'NIGEL';
        break;
      default:
        speakerColor = Colors.white70;
        displayName = _subtitleSpeaker.toUpperCase();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: AnimatedOpacity(
        opacity: _subtitleVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: speakerColor.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: speakerColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Speaker name
                if (displayName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: speakerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                // Dialogue text with formatting support
                _buildFormattedText(_subtitleText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Parse and build formatted text with *italics* and **bold** support
  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final List<InlineSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|([^*]+)');

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ));
      } else if (match.group(3) != null) {
        // regular text
        spans.add(TextSpan(
          text: match.group(3),
          style: const TextStyle(color: Colors.white),
        ));
      }
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 18,
          height: 1.4,
          fontFamily: 'sans-serif',
        ),
        children: spans,
      ),
    );
  }

  // ==================== SFX PANEL ====================

  /// SFX button data: name, icon, color, hotkey
  static const List<Map<String, dynamic>> _sfxButtons = [
    {'name': 'rimshot', 'icon': Icons.music_note, 'color': 0xFFFF6B6B, 'key': '1', 'label': 'Rimshot'},
    {'name': 'sad_trombone', 'icon': Icons.sentiment_dissatisfied, 'color': 0xFF4ECDC4, 'key': '2', 'label': 'Sad Trombone'},
    {'name': 'airhorn', 'icon': Icons.volume_up, 'color': 0xFFFFE66D, 'key': '3', 'label': 'Airhorn'},
    {'name': 'laugh_track', 'icon': Icons.emoji_emotions, 'color': 0xFF95E1D3, 'key': '4', 'label': 'Laugh Track'},
    {'name': 'drumroll', 'icon': Icons.sports_martial_arts, 'color': 0xFFF38181, 'key': '5', 'label': 'Drumroll'},
    {'name': 'whoosh', 'icon': Icons.air, 'color': 0xFF7B68EE, 'key': '6', 'label': 'Whoosh'},
    {'name': 'ding', 'icon': Icons.notifications_active, 'color': 0xFFFFD93D, 'key': '7', 'label': 'Ding'},
    {'name': 'buzzer', 'icon': Icons.cancel, 'color': 0xFFFF4757, 'key': '8', 'label': 'Buzzer'},
  ];

  /// Build the SFX trigger buttons panel
  Widget _buildSfxPanel() {
    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header with collapse toggle
          GestureDetector(
            onTap: () => setState(() => _sfxPanelExpanded = !_sfxPanelExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, color: Colors.purple, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'SFX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _sfxPanelExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Expandable button grid
          if (_sfxPanelExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _sfxButtons.sublist(0, 4).map((sfx) => _buildSfxButton(sfx)).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _sfxButtons.sublist(4, 8).map((sfx) => _buildSfxButton(sfx)).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build individual SFX button
  Widget _buildSfxButton(Map<String, dynamic> sfx) {
    final color = Color(sfx['color'] as int);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: '${sfx['label']} (${sfx['key']})',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _playSfx(sfx['name'] as String),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.8), color.withOpacity(0.5)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(sfx['icon'] as IconData, color: Colors.white, size: 22),
                  const SizedBox(height: 2),
                  Text(sfx['key'] as String, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Play SFX by name
  void _playSfx(String name) {
    SoundEffects().play(name);
    debugPrint('SFX: Playing $name');
  }

  // ==================== PLAY/PAUSE DIALOGUE ====================

  /// Build the Play/Pause button
  Widget _buildPlayPauseButton() {
    final isPlaying = _dialoguePlaying && !_dialoguePaused;
    final isPaused = _dialoguePlaying && _dialoguePaused;

    return Positioned(
      bottom: 120,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Main Play/Pause button
          GestureDetector(
            onTap: _toggleDialogue,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPlaying
                      ? [Colors.green.shade400, Colors.green.shade700]
                      : isPaused
                          ? [Colors.orange.shade400, Colors.orange.shade700]
                          : [Colors.purple.shade400, Colors.purple.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPlaying ? Colors.green : isPaused ? Colors.orange : Colors.purple).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Status label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPlaying ? 'PLAYING' : isPaused ? 'PAUSED' : 'DIALOGUE',
              style: TextStyle(
                color: isPlaying ? Colors.green : isPaused ? Colors.orange : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Stop button (only when playing or paused)
          if (_dialoguePlaying)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _stopDialogue,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade700,
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Toggle dialogue play/pause
  void _toggleDialogue() {
    if (!_dialoguePlaying) {
      // Start playing
      _startDialogue();
    } else if (_dialoguePaused) {
      // Resume
      _resumeDialogue();
    } else {
      // Pause
      _pauseDialogue();
    }
  }

  /// Start the dialogue
  void _startDialogue() {
    setState(() {
      _dialoguePlaying = true;
      _dialoguePaused = false;
      _dialogueIndex = 0;
    });
    debugPrint('Dialogue: Started');
    _playNextLine();
  }

  /// Pause the dialogue
  void _pauseDialogue() {
    _dialogueTimer?.cancel();
    setState(() => _dialoguePaused = true);
    debugPrint('Dialogue: Paused');
  }

  /// Resume the dialogue
  void _resumeDialogue() {
    setState(() => _dialoguePaused = false);
    debugPrint('Dialogue: Resumed');
    _playNextLine();
  }

  /// Stop the dialogue
  void _stopDialogue() {
    _dialogueTimer?.cancel();
    setState(() {
      _dialoguePlaying = false;
      _dialoguePaused = false;
      _dialogueIndex = 0;
    });
    clearSubtitle();
    debugPrint('Dialogue: Stopped');
  }

  /// Play the next dialogue line with TTS voice audio
  Future<void> _playNextLine() async {
    if (!_dialoguePlaying || _dialoguePaused) return;

    if (_dialogueIndex >= _sampleDialogue.length) {
      // Loop back to start
      _dialogueIndex = 0;
    }

    final line = _sampleDialogue[_dialogueIndex];
    final speaker = line['speaker'] ?? 'terry';
    final text = line['text'] ?? '';

    // Show subtitle immediately
    showSubtitle(speaker, text);

    // Strip markdown for TTS (remove ** and * formatting)
    final cleanText = text.replaceAll(RegExp(r'\*+'), '');

    // Generate and play voice audio using ElevenLabs TTS
    debugPrint('TTS: ttsEnabled=${WFLConfig.ttsEnabled}, key=${WFLConfig.elevenLabsKey.substring(0, 8)}...');
    if (WFLConfig.ttsEnabled) {
      try {
        final voiceId = speaker == 'terry'
            ? WFLConfig.terryVoiceId
            : WFLConfig.nigelVoiceId;
        debugPrint('TTS: Generating for $speaker with voice $voiceId');

        // Generate speech audio (returns PCM 44100Hz 16-bit mono)
        final pcmBytes = await _autoRoast.generateSpeech(cleanText, voiceId, character: speaker);
        debugPrint('TTS: Got ${pcmBytes.length} bytes');

        if (pcmBytes.isNotEmpty && mounted && _dialoguePlaying && !_dialoguePaused) {
          // Convert PCM to WAV by adding header
          final wavBytes = _pcmToWav(pcmBytes);

          // Save to temp file and play
          final tempDir = await getTemporaryDirectory();
          final audioFile = File('${tempDir.path}/dialogue_${speaker}_$_dialogueIndex.wav');
          await audioFile.writeAsBytes(wavBytes);

          // Set mouth to talking
          setState(() {
            if (speaker == 'terry') {
              _terryMouth = 'aa';
            } else {
              _nigelMouth = 'aa';
            }
          });

          // Play audio using Windows native player (bypass audioplayers bug)
          final wavPath = audioFile.path.replaceAll('/', '\\');
          debugPrint('TTS: Playing $wavPath');
          Process.run('powershell', [
            '-Command',
            "(New-Object Media.SoundPlayer '$wavPath').PlaySync()",
          ]);

          // Simple lip-sync animation while audio plays
          _animateLipSync(speaker, cleanText.length);
        }
      } catch (e) {
        debugPrint('TTS Error: $e');
      }
    }

    // Play a random SFX occasionally
    if (_dialogueIndex % 3 == 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (speaker == 'terry') {
          _playSfx('rimshot');
        } else {
          _playSfx('ding');
        }
      });
    }

    _dialogueIndex++;

    // Schedule next line (wait for audio + buffer)
    // Estimate: ~80ms per character for TTS + 1s buffer
    final delay = Duration(milliseconds: 2000 + (cleanText.length * 80));
    _dialogueTimer = Timer(delay, _playNextLine);
  }

  /// Convert PCM audio data to WAV format by adding header
  /// ElevenLabs returns PCM: 44100Hz, 16-bit, mono
  List<int> _pcmToWav(List<int> pcmBytes) {
    final sampleRate = 44100;
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = pcmBytes.length;
    final fileSize = 36 + dataSize;

    // Build WAV header (44 bytes)
    final header = <int>[
      // RIFF header
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      fileSize & 0xFF, (fileSize >> 8) & 0xFF, (fileSize >> 16) & 0xFF, (fileSize >> 24) & 0xFF,
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      // fmt subchunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // Subchunk1Size (16 for PCM)
      1, 0, // AudioFormat (1 = PCM)
      numChannels, 0, // NumChannels
      sampleRate & 0xFF, (sampleRate >> 8) & 0xFF, (sampleRate >> 16) & 0xFF, (sampleRate >> 24) & 0xFF,
      byteRate & 0xFF, (byteRate >> 8) & 0xFF, (byteRate >> 16) & 0xFF, (byteRate >> 24) & 0xFF,
      blockAlign, 0, // BlockAlign
      bitsPerSample, 0, // BitsPerSample
      // data subchunk
      0x64, 0x61, 0x74, 0x61, // "data"
      dataSize & 0xFF, (dataSize >> 8) & 0xFF, (dataSize >> 16) & 0xFF, (dataSize >> 24) & 0xFF,
    ];

    return [...header, ...pcmBytes];
  }

  /// Animate lip sync for duration based on text length
  void _animateLipSync(String speaker, int textLength) {
    final mouthShapes = ['aa', 'ee', 'oh', 'oo', 'x'];
    var shapeIndex = 0;

    // Change mouth shape every 100ms while speaking
    final duration = textLength * 60; // ~60ms per character
    final interval = 100;
    var elapsed = 0;

    Timer.periodic(Duration(milliseconds: interval), (timer) {
      if (elapsed >= duration || !_dialoguePlaying) {
        timer.cancel();
        // Reset to closed mouth
        setState(() {
          if (speaker == 'terry') {
            _terryMouth = 'x';
          } else {
            _nigelMouth = 'x';
          }
        });
        return;
      }

      setState(() {
        final shape = mouthShapes[shapeIndex % mouthShapes.length];
        if (speaker == 'terry') {
          _terryMouth = shape;
        } else {
          _nigelMouth = shape;
        }
      });

      shapeIndex++;
      elapsed += interval;
    });
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

  const ExportPreset(this.name, this.resolution, this.fps, this.crf, this.description);

  static const youtube = ExportPreset('YouTube', '1080x720', 30, 18, '~120MB/min, crisp');
  static const stream = ExportPreset('Stream', '1080x720', 30, 24, '~80MB/min, fast');
  static const gif = ExportPreset('GIF Loop', '720x480', 15, 28, '~10MB, viral bait');
}
