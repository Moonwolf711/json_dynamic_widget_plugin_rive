import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:video_player/video_player.dart';

import 'action_dispatcher.dart';
import 'bone_animation.dart';
import 'dev_commands.dart';
// Stubbed for Windows build - mic recording not supported
import 'record_stub.dart';
// file_picker removed - using drag-and-drop instead
// RIVE DISABLED: Using custom bone animation to avoid Windows path length issues
// import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'rive_stub.dart'; // Stub classes when Rive is disabled
import 'sound_effects.dart';
import 'wfl_ai_chat_dev.dart';
import 'wfl_config.dart';
import 'wfl_controller.dart';
import 'wfl_data_binding.dart';
import 'wfl_focus_mode.dart';
import 'wfl_image_resizer.dart';
import 'wfl_layer_manager.dart';
import 'wfl_models.dart';
import 'wfl_uploader.dart';
import 'wfl_websocket.dart';
import 'widgets/wfl_bottom_controls.dart';
import 'widgets/wfl_character.dart';
import 'widgets/wfl_hotkey_hints.dart';
import 'widgets/wfl_play_pause_button.dart';
import 'widgets/wfl_portholes.dart';
import 'widgets/wfl_queue_panel.dart';
import 'widgets/wfl_sfx_panel.dart';
import 'widgets/wfl_subtitle_bar.dart';
import 'widgets/wfl_top_bar.dart';
import 'widgets/wfl_warp_hud.dart';


class WFLAnimator extends StatefulWidget {
  const WFLAnimator({super.key});

  @override
  State<WFLAnimator> createState() => _WFLAnimatorState();
}

class _WFLAnimatorState extends State<WFLAnimator>
    with TickerProviderStateMixin
    implements DevCommandExecutor {
  // Baked static images - loaded once, never again
  late final Image _spaceship;
  // Body images removed - using bone animation system instead
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

  // Capture key for recording
  final GlobalKey _captureKey = GlobalKey();

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
  int _frameCount = 0;
  Timer? _recordingTimer;
  Timer? _frameTimer;
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
  final double _terryBodyScale = 1.0;
  final Offset _terryBodyOffset = Offset.zero;
  final double _terryEyesScale = 1.0;
  final Offset _terryEyesOffset = Offset.zero;
  final double _terryMouthScale = 1.0;
  final Offset _terryMouthOffset = Offset.zero;

  // Nigel components
  final double _nigelBodyScale = 1.0;
  final Offset _nigelBodyOffset = Offset.zero;
  final double _nigelEyesScale = 1.0;
  final Offset _nigelEyesOffset = Offset.zero;
  final double _nigelMouthScale = 1.0;
  final Offset _nigelMouthOffset = Offset.zero;

  // Animation state for PNG fallback character rendering
  // These are used by _buildPngCharacter when Rive is not available
  double _terryEyeX = 0.0;
  double _terryEyeY = 0.0;
  double _nigelEyeX = 0.0;
  double _nigelEyeY = 0.0;
  final double _terryHeadBob = 0.0;
  final double _nigelHeadBob = 0.0;
  final double _terrySway = 0.0;
  final double _nigelSway = 0.0;
  final double _terryLean = 0.0;
  final double _nigelLean = 0.0;
  final double _breathOffset = 0.0;

  // Scale limits
  static const double _minScale = 0.3;
  static const double _maxScale = 3.0;
  static const double _defaultScale = 1.0;

  // Subtitle system
  final String _subtitleText = '';
  final String _subtitleSpeaker = ''; // 'terry', 'nigel', or '' for narrator
  final bool _subtitleVisible = false;
  Timer? _subtitleTimer;

  // SFX Panel
  final bool _sfxPanelExpanded = true; // Start expanded so user sees buttons

  // NOTE: HeadBob, Sway, Lean now handled by MirrorAnimationBuilder + MovieTween
  // See _buildCharacterWithComponents() and _buildPngCharacter() for usage

  // Show Mode - auto-commentary
  bool _showMode = false;
  Timer? _showModeTimer;
  int _currentSpeaker = 0; // 0 = terry, 1 = nigel, alternates
  bool _isGeneratingCommentary = false;

  // Dialogue playback state
  final bool _dialoguePlaying = false;
  final bool _dialoguePaused = false;
  Timer? _dialogueTimer;
  final int _dialogueIndex = 0;

  // Sample dialogue lines for demo
  static const List<Map<String, String>> _sampleDialogue = [
    {
      'speaker': 'terry',
      'text':
          'Yo, welcome to **Wooking for Love**! I\'m Terry, your host with the most!'
    },
    {
      'speaker': 'nigel',
      'text': 'And I\'m Nigel. *Reluctantly* here to provide... commentary.'
    },
    {
      'speaker': 'terry',
      'text': 'Tonight we got some FIRE contestants lined up!'
    },
    {
      'speaker': 'nigel',
      'text':
          'Indeed. Though I suspect the only thing *fire* will be my scathing observations.'
    },
    {'speaker': 'terry', 'text': 'Bruh, you gotta chill! This is about LOVE!'},
    {'speaker': 'nigel', 'text': 'Love? In THIS economy? **Doubtful.**'},
    {
      'speaker': 'terry',
      'text': 'Aight let\'s bring out our first contestant!'
    },
    {'speaker': 'nigel', 'text': 'Brace yourselves. Here comes the *cringe*.'},
    {'speaker': 'terry', 'text': 'Yo that outfit is straight BUSSIN!'},
    {
      'speaker': 'nigel',
      'text': 'If by *bussin* you mean a fashion disaster, then yes.'
    },
    {'speaker': 'terry', 'text': 'Nigel why you always gotta be so negative?'},
    {'speaker': 'nigel', 'text': 'I prefer the term **realistic**, Terry.'},
  ];

  // Reaction animations
  String _terryReaction =
      'neutral'; // neutral, laughing, shocked, facepalm, pointing, thinking
  String _nigelReaction = 'neutral';
  Timer? _reactionTimer;

  // Character-specific facial feature positions

  // WARP MODE - flying through video
  bool _isWarp = false;
  VideoPlayerController? _warpPlayer;
  final double _warpSpeed = 0.87; // c units

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
    // Body images removed - using bone animation system with layers
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
<<<<<<< HEAD
    // DISABLED: Using PNG layer system with MirrorAnimationBuilder for now
    // _loadSkeletons();
=======
    _loadSkeletons();
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc

    // Start background music on app open (dating show vibe!)
    SoundEffects().startBackgroundMusic();

    // Demo subtitle sequence (shows subtitle system works)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        showSubtitle(
            'terry', "G'day legends! Welcome to **Wooking for Love**!");
      }
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        showSubtitle('nigel',
            "Indeed. I must say, this is *quite* the peculiar situation.");
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

      debugPrint(
          'Terry artboard: ${terryArtboard != null ? "found" : "not found"}');
      debugPrint(
          'Nigel artboard: ${nigelArtboard != null ? "found" : "not found"}');

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
        _terryStateMachine = StateMachineController.fromArtboard(
                _terryArtboard!, 'character') ??
            StateMachineController.fromArtboard(_terryArtboard!, 'cockpit') ??
            StateMachineController.fromArtboard(_terryArtboard!, 'talker') ??
            StateMachineController.fromArtboard(
                _terryArtboard!, 'State Machine 1');

        if (_terryStateMachine != null) {
          _terryArtboard!.addController(_terryStateMachine!);
          debugPrint(
              'Terry state machine: ${_terryStateMachine!.stateMachine.name}');
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
        _nigelStateMachine = StateMachineController.fromArtboard(
                _nigelArtboard!, 'character') ??
            StateMachineController.fromArtboard(_nigelArtboard!, 'cockpit') ??
            StateMachineController.fromArtboard(_nigelArtboard!, 'talker') ??
            StateMachineController.fromArtboard(
                _nigelArtboard!, 'State Machine 1');

        if (_nigelStateMachine != null) {
          _nigelArtboard!.addController(_nigelStateMachine!);
          debugPrint(
              'Nigel state machine: ${_nigelStateMachine!.stateMachine.name}');
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
        debugPrint(
            'Rive bone animations loaded: terry=${_terryArtboard != null}, nigel=${_nigelArtboard != null}');
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
<<<<<<< HEAD
      _terrySkeleton =
          await loadSkeleton('assets/skeletons/terry_skeleton.json');
      debugPrint(
          'Terry skeleton loaded: ${_terrySkeleton!.bones.length} bones, ${_terrySkeleton!.animations.length} animations');

      // Load Nigel skeleton
      _nigelSkeleton =
          await loadSkeleton('assets/skeletons/nigel_skeleton.json');
      debugPrint(
          'Nigel skeleton loaded: ${_nigelSkeleton!.bones.length} bones, ${_nigelSkeleton!.animations.length} animations');
=======
      _terrySkeleton = await loadSkeleton('assets/skeletons/terry_skeleton.json');
      debugPrint('Terry skeleton loaded: ${_terrySkeleton!.bones.length} bones, ${_terrySkeleton!.animations.length} animations');

      // Load Nigel skeleton
      _nigelSkeleton = await loadSkeleton('assets/skeletons/nigel_skeleton.json');
      debugPrint('Nigel skeleton loaded: ${_nigelSkeleton!.bones.length} bones, ${_nigelSkeleton!.animations.length} animations');
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc

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

      case 'refresh_character':
        // Hot-reload all assets for a character (from designer wizard)
        final character = payload['character'] as String?;
        if (character != null) {
          _reloadCharacterAssets(character);
        }
        break;

      case 'asset_uploaded':
        // Hot-reload single asset (from designer upload)
        final character = payload['character'] as String?;
        final layer = payload['layer'] as String?;
        final asset = payload['asset'] as String?;
        final path = payload['path'] as String?;
        if (character != null && layer != null && asset != null) {
          _hotReloadAsset(character, layer, asset, path);
        }
        break;

      case 'preview_asset':
        // Preview specific asset in viewer
        final character = payload['character'] as String?;
        final layer = payload['layer'] as String?;
        final asset = payload['asset'] as String?;
        final path = payload['path'] as String?;
        if (character != null && asset != null) {
          _previewAsset(character, layer ?? 'mouth_shapes', asset, path);
        }
        break;
    }
  }

  /// Reload all assets for a character (skeleton + images)
  Future<void> _reloadCharacterAssets(String character) async {
    debugPrint('Hot-reload: Refreshing all assets for $character');

    // Clear image cache for this character's assets
    _evictCharacterImages(character);

    // Reload skeleton
    try {
      final skeleton =
          await loadSkeleton('assets/skeletons/${character}_skeleton.json');
      setState(() {
        if (character == 'terry') {
          _terrySkeleton = skeleton;
        } else if (character == 'nigel') {
          _nigelSkeleton = skeleton;
        }
        _skeletonsLoaded = true;
      });
      debugPrint(
          'Hot-reload: $character skeleton reloaded (${skeleton.bones.length} bones)');
    } catch (e) {
      debugPrint('Hot-reload: Failed to reload $character skeleton: $e');
    }

    // Notify uploader that refresh is complete
    _wsClient.sendPreviewReady('all', character);
  }

  /// Hot-reload a single asset (evict from cache and refresh UI)
  void _hotReloadAsset(
      String character, String layer, String asset, String? path) {
    debugPrint('Hot-reload: $character/$layer/$asset');

    // Build the asset path to evict
    final assetPath = 'assets/characters/$character/$layer/$asset.png';

    // Evict from image cache
    final key = AssetImage(assetPath);
    imageCache.evict(key);
    debugPrint('Hot-reload: Evicted $assetPath from cache');

    // If it's a mouth shape, update the current mouth to show it
    if (layer == 'mouth_shapes') {
      final mouthName = asset.replaceAll('.png', '').replaceAll('.svg', '');
      setState(() {
        if (character == 'terry') {
          _terryMouth = mouthName;
        } else if (character == 'nigel') {
          _nigelMouth = mouthName;
        }
      });
      debugPrint('Hot-reload: Set $character mouth to $mouthName');
    }

    // Force UI refresh
    setState(() {});

    // Notify uploader that asset is loaded
    _wsClient.sendAssetLoaded(character, layer, asset);
  }

  /// Preview a specific asset (set it as active and show in viewer)
  void _previewAsset(
      String character, String layer, String asset, String? path) {
    debugPrint('Preview: $character/$layer/$asset');

    // Evict any cached version first
    final assetPath = 'assets/characters/$character/$layer/$asset.png';
    imageCache.evict(AssetImage(assetPath));

    // Set the appropriate state based on layer type
    setState(() {
      if (layer == 'mouth_shapes') {
        // Show this mouth shape
        final mouthName = asset.replaceAll('.png', '').replaceAll('.svg', '');
        if (character == 'terry') {
          _terryMouth = mouthName;
        } else {
          _nigelMouth = mouthName;
        }
      } else if (layer == 'eyes') {
        // Show this eye state
        final eyeState = asset.replaceAll('eyes_', '').replaceAll('.png', '');
        if (character == 'terry') {
          _terryBlinkState = eyeState;
        } else {
          _nigelBlinkState = eyeState;
        }
      }
    });

    // Notify uploader that preview is showing
    _wsClient.sendPreviewReady(asset, character);
  }

  /// Evict all cached images for a character
  void _evictCharacterImages(String character) {
    // Common image paths for WFL characters
    final paths = [
      // Mouth shapes
      'assets/characters/$character/mouth_shapes/a.png',
      'assets/characters/$character/mouth_shapes/e.png',
      'assets/characters/$character/mouth_shapes/f.png',
      'assets/characters/$character/mouth_shapes/i.png',
      'assets/characters/$character/mouth_shapes/l.png',
      'assets/characters/$character/mouth_shapes/m.png',
      'assets/characters/$character/mouth_shapes/o.png',
      'assets/characters/$character/mouth_shapes/u.png',
      'assets/characters/$character/mouth_shapes/x.png',
      'assets/characters/$character/mouth_shapes/rest.png',
      'assets/characters/$character/mouth_shapes/smirk.png',
      // Eyes
      'assets/characters/$character/eyes/eyes_open.png',
      'assets/characters/$character/eyes/eyes_closed.png',
      'assets/characters/$character/eyes/eyes_half.png',
      'assets/characters/$character/eyes/eyes_squint.png',
      'assets/characters/$character/eyes/eyes_wide.png',
    ];

    // Also evict numbered layers (terry has 20, nigel has 15)
    for (int i = 0; i <= 25; i++) {
      paths.add('assets/characters/$character/layers/layer_$i.png');
      paths.add(
          'assets/characters/$character/layers/${i.toString().padLeft(2, '0')}.png');
    }

    // Evict each path from cache
    for (final path in paths) {
      imageCache.evict(AssetImage(path));
    }
    debugPrint(
        'Hot-reload: Evicted ${paths.length} cached images for $character');
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  /// Start blink timer - random blinks every 2-5 seconds
  /// Manually trigger a single blink animation
  void _triggerBlink(String character) {
    setState(() {
      if (character == 'terry') {
        _terryBlinkState = 'half';
      } else if (character == 'nigel') {
        _nigelBlinkState = 'half';
      }
    });

    // Blink sequence: half -> closed -> half -> open
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          if (character == 'terry') {
            _terryBlinkState = 'closed';
          } else if (character == 'nigel') {
            _nigelBlinkState = 'closed';
          }
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          if (character == 'terry') {
            _terryBlinkState = 'half';
          } else if (character == 'nigel') {
            _nigelBlinkState = 'half';
          }
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          if (character == 'terry') {
            _terryBlinkState = 'open';
          } else if (character == 'nigel') {
            _nigelBlinkState = 'open';
          }
        });
      }
    });
  }

  /// All other animation (breathing, sway, headBob, lean) handled by MirrorAnimationBuilder
  void _startBlinkTimer() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 2000 + 500), (_) {
      // Random delay between blinks (2-5 seconds)
      if (_random.nextDouble() > 0.4)
        return; // 60% chance to skip = varied timing

      // Start blink sequence with smooth transitions
      if (!mounted) return;
      setState(() {
        _terryBlinkState = 'half';
        _nigelBlinkState = 'half';
      });

      // Natural blink sequence (asymmetric timing)
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted)
          setState(() {
            _terryBlinkState = 'closed';
            _nigelBlinkState = 'closed';
          });
      });
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted)
          setState(() {
            _terryBlinkState = 'half';
            _nigelBlinkState = 'half';
          });
      });
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted)
          setState(() {
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
      _frameCount = 0;
      _capturedFrames.clear();
    });

    // Create frames directory
    getTemporaryDirectory().then((tempDir) {
      final framesPath = '${tempDir.path}/wfl_frames';
      final framesDir = Directory(framesPath);
      if (framesDir.existsSync()) {
        framesDir.deleteSync(recursive: true);
      }
      framesDir.createSync(recursive: true);
    });

    // Timer for seconds display + auto-stop at 60s
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 60) {
        _stopRecording();
      }
    });

    // 30fps frame capture
    _frameTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _captureFrame();
    });

    debugPrint('Recording started - 30fps, RepaintBoundary capture');
  }

  Future<void> _captureFrame() async {
    if (!_isRecording) return;

    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final framesPath = '${tempDir.path}/wfl_frames';

      final frameFile =
          File('$framesPath/${_frameCount.toString().padLeft(4, '0')}.png');
      await frameFile.writeAsBytes(bytes);
      _frameCount++;
    } catch (e) {
      // Silently fail to avoid console flooding during recording
    }
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    _frameTimer?.cancel();
    setState(() => _isRecording = false);

    // Show export dialog
    if (!mounted) return;
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
      if (!mounted) return;
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
      if (connected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube connected! Ready to post.')),
        );
      }
      setState(() {});
    }
  }

  // ============================================================================
  // DEV COMMANDS EXECUTOR - Allows AI chat to control the show in real-time
  // ============================================================================

  @override
  Future<CommandResult> animateCharacter(
      String character, String animation) async {
    try {
      setState(() {
        if (character == 'terry') {
          _terryAnimation = animation;
          _terryBoneKey.currentState?.setAnimation(animation);
        } else if (character == 'nigel') {
          _nigelAnimation = animation;
          _nigelBoneKey.currentState?.setAnimation(animation);
        }
      });
      return CommandResult.success('✓ Animated $character: $animation');
    } catch (e) {
      return CommandResult.error('Failed to animate $character: $e');
    }
  }

  @override
  Future<CommandResult> setMouthShape(String character, String shape) async {
    try {
      setState(() {
        if (character == 'terry') {
          _terryMouth = shape;
        } else if (character == 'nigel') {
          _nigelMouth = shape;
        }
      });
      return CommandResult.success('✓ Set $character mouth: $shape');
    } catch (e) {
      return CommandResult.error('Failed to set mouth shape: $e');
    }
  }

  @override
  Future<CommandResult> triggerBlink(String character) async {
    try {
      if (character == 'both') {
        _triggerBlink('terry');
        _triggerBlink('nigel');
        return CommandResult.success('✓ Both characters blinked');
      } else {
        _triggerBlink(character);
        return CommandResult.success('✓ $character blinked');
      }
    } catch (e) {
      return CommandResult.error('Failed to trigger blink: $e');
    }
  }

  @override
  Future<CommandResult> playSFX(String sfxName) async {
    try {
      await SoundEffects().play(sfxName);
      return CommandResult.success('✓ Played SFX: $sfxName');
    } catch (e) {
      return CommandResult.error('Failed to play SFX: $e');
    }
  }

  @override
  Future<CommandResult> setScale(String character, double scale) async {
    // Scale requires widget tree rebuild - not yet implemented
    // Would need to add _terryScale/_nigelScale state variables
    return CommandResult.error(
      'Character scaling not yet supported (requires widget tree changes)',
    );
  }

  @override
  Future<CommandResult> moveCharacter(
      String character, double x, double y) async {
    // Character positions are fixed in the cockpit layout
    // This would require architectural changes to support
    return CommandResult.error(
      'Character positioning not yet supported (fixed cockpit layout)',
    );
  }

  @override
  Future<CommandResult> addLayer(String character, String layerPath) async {
    // Layer system integration - future feature
    return CommandResult.error(
      'Layer adding not yet supported - use Layer Manager UI',
    );
  }

  @override
  Future<CommandResult> executeCustomCode(String code) async {
    // Security: Custom code execution disabled for safety
    return CommandResult.error(
      'Custom code execution disabled for security',
    );
  }

  @override
  List<String> getAvailableCommands() {
    return [
      'animate [terry|nigel] [idle|talking|blink|excited]',
      'set [terry|nigel] mouth [a|e|i|o|u|x]',
      'blink [terry|nigel|both]',
      'play [sfx_name]',
      'scale [terry|nigel] [size]',
    ];
  }

  @override
  Map<String, dynamic> getStateInfo() {
    return {
      'terry': {
        'animation': _terryAnimation,
        'mouth': _terryMouth,
        'skeleton_loaded': _terrySkeleton != null,
      },
      'nigel': {
        'animation': _nigelAnimation,
        'mouth': _nigelMouth,
        'skeleton_loaded': _nigelSkeleton != null,
      },
      'audio_playing': _voicePlayer.state == PlayerState.playing,
    };
  }

  // ============================================================================
  // END DEV COMMANDS
  // ============================================================================

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
<<<<<<< HEAD
      _buttonState = controller.findInput<double>(RiveInput.buttonState.name)
          as SMINumber?;
      // Note: String inputs don't exist in Rive - btnTarget removed
      _isTalking =
          controller.findInput<bool>(RiveInput.isTalking.name) as SMIBool?;
=======
      _buttonState = controller.findInput<double>(RiveInput.buttonState.name) as SMINumber?;
      // Note: String inputs don't exist in Rive - btnTarget removed
      _isTalking = controller.findInput<bool>(RiveInput.isTalking.name) as SMIBool?;
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc
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
        const SnackBar(
            content: Text('Flythrough Mode OFF - 3 independent videos')),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
        const SnackBar(
            content: Text('Load videos first, then start Show Mode!')),
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
        if (_porthole1?.value.isInitialized ?? false)
          activePlayer = _porthole1;
        else if (_porthole2?.value.isInitialized ?? false)
          activePlayer = _porthole2;
        else if (_porthole3?.value.isInitialized ?? false)
          activePlayer = _porthole3;
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
      final voiceId = character == 'nigel'
          ? _autoRoast.nigelVoiceId
          : _autoRoast.terryVoiceId;
      final audioBytes =
          await _autoRoast.generateSpeech(roast, voiceId, character: character);

      if (audioBytes.isNotEmpty && _showMode) {
        // Save and play
        final tempDir = Directory.systemTemp;
        final audioFile = File(
            '${tempDir.path}/show_${character}_${DateTime.now().millisecondsSinceEpoch}.mp3');
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
  void _triggerReaction(String character, String reaction,
      {Duration duration = const Duration(seconds: 2)}) {
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
      final voiceId =
          window == 2 ? _autoRoast.nigelVoiceId : _autoRoast.terryVoiceId;

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
  Future<void> _playWithLipSync(
      String audioPath, String character, String text) async {
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

      final elapsed =
          DateTime.now().difference(_audioStartTime!).inMilliseconds / 1000.0;
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
      final voiceId = character == 'nigel'
          ? _autoRoast.nigelVoiceId
          : _autoRoast.terryVoiceId;

      // Generate TTS audio (PCM format)
      final pcmBytes =
          await _autoRoast.generateSpeech(text, voiceId, character: character);

      if (pcmBytes.isNotEmpty) {
        // Convert PCM to WAV by adding header
        final wavBytes = _createWavFromPcm(pcmBytes, 44100, 1, 16);

        // Save as WAV file
        final tempDir = Directory.systemTemp;
        final audioFile = File(
            '${tempDir.path}/say_${character}_${DateTime.now().millisecondsSinceEpoch}.wav');
        await audioFile.writeAsBytes(wavBytes);

        // Notify server first
        _wsClient
            .sendStatus('speaking', {'character': character, 'text': text});

        // Start lip-sync animation
        _currentCues = _generateMouthCues(text);
        _cueIndex = 0;
        _audioStartTime = DateTime.now();
        _setTalking(character, true);

        // Start lip-sync timer
        _lipSyncTimer?.cancel();
        _lipSyncTimer =
            Timer.periodic(const Duration(milliseconds: 16), (timer) {
          if (_audioStartTime == null || _cueIndex >= _currentCues.length) {
            timer.cancel();
            _setMouth(character, 'x');
            _setTalking(character, false);
            return;
          }
          final elapsed =
              DateTime.now().difference(_audioStartTime!).inMilliseconds /
                  1000.0;
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
  List<int> _createWavFromPcm(
      List<int> pcmData, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = <int>[
      // RIFF header
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      fileSize & 0xff, (fileSize >> 8) & 0xff, (fileSize >> 16) & 0xff,
      (fileSize >> 24) & 0xff,
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      // fmt chunk
      0x66, 0x6d, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // chunk size
      1, 0, // audio format (PCM)
      channels & 0xff, (channels >> 8) & 0xff,
      sampleRate & 0xff, (sampleRate >> 8) & 0xff, (sampleRate >> 16) & 0xff,
      (sampleRate >> 24) & 0xff,
      byteRate & 0xff, (byteRate >> 8) & 0xff, (byteRate >> 16) & 0xff,
      (byteRate >> 24) & 0xff,
      blockAlign & 0xff, (blockAlign >> 8) & 0xff,
      bitsPerSample & 0xff, (bitsPerSample >> 8) & 0xff,
      // data chunk
      0x64, 0x61, 0x74, 0x61, // "data"
      dataSize & 0xff, (dataSize >> 8) & 0xff, (dataSize >> 16) & 0xff,
      (dataSize >> 24) & 0xff,
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
      final voiceId = character == 'nigel'
          ? _autoRoast.nigelVoiceId
          : _autoRoast.terryVoiceId;
      final audioBytes =
          await _autoRoast.generateSpeech(roast, voiceId, character: character);

      if (audioBytes.isNotEmpty) {
        // Save temp audio
        final tempDir = Directory.systemTemp;
        final audioFile = File(
            '${tempDir.path}/roast_${character}_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await audioFile.writeAsBytes(audioBytes);

        // Play with lip-sync
        await _playWithLipSync(audioFile.path, character, roast);

        // Notify server
        _wsClient
            .sendStatus('roasted', {'character': character, 'roast': roast});
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

      if ('aáà'.contains(char))
        mouth = 'a';
      else if ('eéè'.contains(char))
        mouth = 'e';
      else if ('iíì'.contains(char))
        mouth = 'i';
      else if ('oóò'.contains(char))
        mouth = 'o';
      else if ('uúù'.contains(char))
        mouth = 'u';
      else if ('fv'.contains(char))
        mouth = 'f';
      else if ('lrw'.contains(char))
        mouth = 'l';
      else if ('mbp'.contains(char))
        mouth = 'm';
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
        autofocus: false, // Focus requested in initState after layout
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
                              child: RepaintBoundary(
                                key: _captureKey,
                                child: ClipRect(
                                  child: GestureDetector(
                                    onTapDown: _onCockpitTap,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // WARP MODE: Full-screen video behind everything
                                        if (_isWarp &&
                                            _warpPlayer != null &&
                                            _warpPlayer!.value.isInitialized)
                                          Positioned.fill(
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                Color.fromRGBO(0, 0, 0, 0.3),
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
                                        Positioned.fill(
                                            child: IgnorePointer(
                                                child: _buttonsPanel)),
                                        _buildPortholes(),
                                        // Characters BEHIND the table - using bone animation system
                                        // Terry - bone animation with layers
                                        Positioned(
                                          left: 50,
                                          bottom: -50,
                                          child: _buildCharacter('terry'),
                                        ),
                                        // Nigel - bone animation with layers
                                        Positioned(
                                          right: 50,
                                          bottom: -50,
                                          child: _buildCharacter('nigel'),
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

<<<<<<< HEAD
                                        // WARP HUD - green text overlay
                                        if (_isWarp) _buildWarpHUD(),
=======
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
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc

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

  Widget _buildTopBar() {
    return WFLTopBar(
      reactMode: _reactMode,
      flythroughMode: _flythroughMode,
      showMode: _showMode,
      isGeneratingCommentary: _isGeneratingCommentary,
      isRecordingMic: _isRecordingMic,
      isLiveMicOn: _isLiveMicOn,
      isRecording: _isRecording,
      recordingSeconds: _recordingSeconds,
      onToggleReactMode: (v) => setState(() => _reactMode = v),
      onToggleFlythroughMode: _toggleFlythroughMode,
      onToggleShowMode: _toggleShowMode,
      onToggleLiveMic: _toggleLiveMic,
      onStartLiveMicRecording: (_) => _startLiveMicRecording(),
      onStopLiveMicRecording: (_) => _stopLiveMicRecording(),
      onToggleRecording: _toggleRecording,
      onShowSavePresetDialog: _showSavePresetDialog,
      onShowLoadPresetDialog: _showLoadPresetDialog,
      onToggleYouTube: _toggleYouTube,
      onShowAIChat: () =>
          WFLAIChatDevDialog.show(context, commandExecutor: this),
      onShowLayerManager: _showLayerManager,
    );
  }

  Widget _buildQueuePanel() {
    return WFLQueuePanel(
      queue: _roastQueue,
      isPlayingQueue: _isPlayingQueue,
      currentQueueIndex: _currentQueueIndex,
      onReorder: _reorderQueue,
      onRemove: _removeFromQueue,
      onPlayQueue: _playQueue,
      onClearQueue: _clearQueue,
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

  /// Show layer manager dialog
  void _showLayerManager() async {
    // Use absolute paths for Windows
    const basePath =
        r'C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\flutter_viewer';
    WFLLayerManager.show(
      context,
      terrySkeletonPath:
          r'C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\flutter_viewer\assets\skeletons\terry_skeleton.json',
      nigelSkeletonPath:
          r'C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\flutter_viewer\assets\skeletons\nigel_skeleton.json',
      terryAssetsPath:
          r'C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\flutter_viewer\assets\characters\terry',
      nigelAssetsPath:
          r'C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\flutter_viewer\assets\characters\nigel',
      onLayersChanged: () {
        // Reload skeletons when layers change
        _loadSkeletons();
      },
    );
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

  Widget _buildVolumeSlider() {
    return WFLBottomControls(
      volume: _volume,
      onVolumeChanged: (v) {
        setState(() => _volume = v);
        _voicePlayer.setVolume(v);
      },
      onExport: _exportVideo,
      onExportAndPost: _exportAndPost,
      roastNumber: WFLUploader.roastNumber,
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

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: Text('Exporting ${preset.name}...',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('${preset.resolution} @ ${preset.fps}fps',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      // Use temp directory - antivirus won't lock it, cleans up automatically
      final tempDir = await getTemporaryDirectory();
      final framesPath = '${tempDir.path}/wfl_frames';
      final outputPath =
          '${tempDir.path}/output_${preset.name.toLowerCase()}.mp4';

      // Clean frames folder first - crashes if leftover from last render
      final framesDir = Directory(framesPath);
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      await framesDir.create();

      // FFmpeg export with preset
      final result = await Process.run('ffmpeg', [
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
          SnackBar(content: Text('Exported: $outputPath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${result.stderr}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
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
      await Process.run('ffmpeg', [
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

      final videoFile = File(outputPath);
      if (!await videoFile.exists()) {
        if (!mounted) return;
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

      if (!mounted) return;
      Navigator.pop(context);

      // 3. Show results
      final youtubeUrl = results['youtube'];
      if (!mounted) return;
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
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post failed: $e')),
      );
    }
  }

  Widget _buildHotkeyHints() {
    return WFLHotkeyHints(
      hasFocus: _hasFocus,
      isWarp: _isWarp,
      flythroughMode: _flythroughMode,
      onRequestFocus: () => _focusNode.requestFocus(),
    );
  }

  /// WARP HUD - green text, fake spaceship display
  Widget _buildWarpHUD() {
    return WFLWarpHUD(warpSpeed: _warpSpeed);
  }

  Widget _buildPortholes() {
    return WFLPortholes(
      flythroughMode: _flythroughMode,
      flythroughVideo: _flythroughVideo,
      porthole1: _porthole1,
      porthole2: _porthole2,
      porthole3: _porthole3,
      onPortholeDropped: _onPortholeDropped,
    );
  }

  /// Build character using Rive bone animation (preferred) or transparent PNG fallback
  /// Rive provides smooth bone-based animations, PNG is used as fallback
  /// Build character using WFLCharacter widget
  Widget _buildCharacter(String name) {
    final reactionMods = _getReactionModifiers(name);

<<<<<<< HEAD
    return WFLCharacter(
      name: name,
      riveLoaded: _riveLoaded,
      riveArtboard: name == 'terry' ? _terryArtboard : _nigelArtboard,
      skeletonsLoaded: _skeletonsLoaded,
      skeleton: name == 'terry' ? _terrySkeleton : _nigelSkeleton,
      boneAnimation: name == 'terry' ? _terryAnimation : _nigelAnimation,
      boneKey: name == 'terry' ? _terryBoneKey : _nigelBoneKey,
      mouthShape: name == 'terry' ? _terryMouth : _nigelMouth,
      blinkState: name == 'terry' ? _terryBlinkState : _nigelBlinkState,
      bobMultiplier: reactionMods['bobMultiplier'] ?? 1.0,
      swayMultiplier: reactionMods['swayMultiplier'] ?? 1.0,
      leanOffset: reactionMods['leanOffset'] ?? 0.0,
      bodyScale: name == 'terry' ? _terryBodyScale : _nigelBodyScale,
      bodyOffset: name == 'terry' ? _terryBodyOffset : _nigelBodyOffset,
      eyesScale: name == 'terry' ? _terryEyesScale : _nigelEyesScale,
      eyesOffset: name == 'terry' ? _terryEyesOffset : _nigelEyesOffset,
      mouthScale: name == 'terry' ? _terryMouthScale : _nigelMouthScale,
      mouthOffset: name == 'terry' ? _terryMouthOffset : _nigelMouthOffset,
      onBodyScaleUpdate: (scale) {
        setState(() {
          if (name == 'terry') {
            _terryBodyScale = scale.clamp(_minScale, _maxScale);
          } else {
            _nigelBodyScale = scale.clamp(_minScale, _maxScale);
          }
        });
      },
      onBodyDragUpdate: (delta) {
        setState(() {
          if (name == 'terry') {
            _terryBodyOffset += delta;
          } else {
            _nigelBodyOffset += Offset(-delta.dx, delta.dy);
          }
        });
      },
      onBodyReset: () {
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
      onEyesScaleUpdate: (scale) {
        setState(() {
          if (name == 'terry') {
            _terryEyesScale = scale.clamp(_minScale, _maxScale);
          } else {
            _nigelEyesScale = scale.clamp(_minScale, _maxScale);
          }
        });
      },
      onEyesDragUpdate: (delta) {
        setState(() {
          if (name == 'terry') {
            _terryEyesOffset += delta;
          } else {
            _nigelEyesOffset += Offset(-delta.dx, delta.dy);
          }
        });
      },
      onEyesReset: () {
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
      onMouthScaleUpdate: (scale) {
        setState(() {
          if (name == 'terry') {
            _terryMouthScale = scale.clamp(_minScale, _maxScale);
          } else {
            _nigelMouthScale = scale.clamp(_minScale, _maxScale);
          }
        });
      },
      onMouthDragUpdate: (delta) {
        setState(() {
          if (name == 'terry') {
            _terryMouthOffset += delta;
          } else {
            _nigelMouthOffset += Offset(-delta.dx, delta.dy);
          }
        });
      },
      onMouthReset: () {
        setState(() {
          if (name == 'terry') {
            _terryMouthScale = _defaultScale;
            _terryMouthOffset = Offset.zero;
          } else {
            _nigelMouthScale = _defaultScale;
            _nigelMouthOffset = Offset.zero;
          }
        });
=======
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
          child: _buildCharacter(name, body, mouth), // Use bone animation if available!
        );
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc
      },
    );
  }

<<<<<<< HEAD
  /// Build character using Rive bone animation
=======
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
      debugPrint('📊 Rendering $name with RIVE');
      return _buildRiveCharacter(name, artboard);
    }

    // Priority 2: Custom bone animation system (if skeletons loaded)
    if (_skeletonsLoaded && skeleton != null) {
      debugPrint('🦴 Rendering $name with BONE ANIMATION (showBones will be true)');
      return _buildBoneCharacter(name, skeleton);
    }

    // Priority 3: PNG layer fallback
    debugPrint('🖼️ Rendering $name with PNG FALLBACK');
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
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc

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
    final displayDuration = duration ??
        Duration(
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
    return WFLSubtitleBar(
      visible: _subtitleVisible,
      speaker: _subtitleSpeaker,
      text: _subtitleText,
    );
  }

  // ==================== SFX PANEL ====================

  /// SFX button data: name, icon, color, hotkey
  static const List<Map<String, dynamic>> _sfxButtons = [
    {
      'name': 'rimshot',
      'icon': Icons.music_note,
      'color': 0xFFFF6B6B,
      'key': '1',
      'label': 'Rimshot'
    },
    {
      'name': 'sad_trombone',
      'icon': Icons.sentiment_dissatisfied,
      'color': 0xFF4ECDC4,
      'key': '2',
      'label': 'Sad Trombone'
    },
    {
      'name': 'airhorn',
      'icon': Icons.volume_up,
      'color': 0xFFFFE66D,
      'key': '3',
      'label': 'Airhorn'
    },
    {
      'name': 'laugh_track',
      'icon': Icons.emoji_emotions,
      'color': 0xFF95E1D3,
      'key': '4',
      'label': 'Laugh Track'
    },
    {
      'name': 'drumroll',
      'icon': Icons.sports_martial_arts,
      'color': 0xFFF38181,
      'key': '5',
      'label': 'Drumroll'
    },
    {
      'name': 'whoosh',
      'icon': Icons.air,
      'color': 0xFF7B68EE,
      'key': '6',
      'label': 'Whoosh'
    },
    {
      'name': 'ding',
      'icon': Icons.notifications_active,
      'color': 0xFFFFD93D,
      'key': '7',
      'label': 'Ding'
    },
    {
      'name': 'buzzer',
      'icon': Icons.cancel,
      'color': 0xFFFF4757,
      'key': '8',
      'label': 'Buzzer'
    },
  ];

  /// Build the SFX trigger buttons panel
  Widget _buildSfxPanel() {
    return WFLSfxPanel(
      isExpanded: _sfxPanelExpanded,
      onToggleExpanded: () =>
          setState(() => _sfxPanelExpanded = !_sfxPanelExpanded),
      sfxButtons: _sfxButtons,
      onPlaySfx: _playSfx,
    );
  }
  // ==================== PLAY/PAUSE DIALOGUE ====================

  /// Play SFX by name
  void _playSfx(String name) {
    SoundEffects().play(name);
    debugPrint('SFX: Playing $name');
  }

  // ==================== PLAY/PAUSE DIALOGUE ====================

  /// Build the Play/Pause button
  Widget _buildPlayPauseButton() {
    return WFLPlayPauseButton(
      dialoguePlaying: _dialoguePlaying,
      dialoguePaused: _dialoguePaused,
      onToggle: _toggleDialogue,
      onStop: _stopDialogue,
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
<<<<<<< HEAD
    debugPrint(
        'TTS: ttsEnabled=${WFLConfig.ttsEnabled}, key=${WFLConfig.elevenLabsKey.substring(0, 8)}...');
=======
    debugPrint('TTS: ttsEnabled=${WFLConfig.ttsEnabled}, key=${WFLConfig.elevenLabsKey.substring(0, 8)}...');
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc
    if (WFLConfig.ttsEnabled) {
      try {
        final voiceId = speaker == 'terry'
            ? WFLConfig.terryVoiceId
            : WFLConfig.nigelVoiceId;
        debugPrint('TTS: Generating for $speaker with voice $voiceId');

        // Generate speech audio (returns PCM 44100Hz 16-bit mono)
<<<<<<< HEAD
        final pcmBytes = await _autoRoast.generateSpeech(cleanText, voiceId,
            character: speaker);
=======
        final pcmBytes = await _autoRoast.generateSpeech(cleanText, voiceId, character: speaker);
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc
        debugPrint('TTS: Got ${pcmBytes.length} bytes');

        if (pcmBytes.isNotEmpty &&
            mounted &&
            _dialoguePlaying &&
            !_dialoguePaused) {
          // Convert PCM to WAV by adding header
          final wavBytes = _pcmToWav(pcmBytes);

          // Save to temp file and play
          final tempDir = await getTemporaryDirectory();
          final audioFile =
              File('${tempDir.path}/dialogue_${speaker}_$_dialogueIndex.wav');
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
      fileSize & 0xFF, (fileSize >> 8) & 0xFF, (fileSize >> 16) & 0xFF,
      (fileSize >> 24) & 0xFF,
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      // fmt subchunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // Subchunk1Size (16 for PCM)
      1, 0, // AudioFormat (1 = PCM)
      numChannels, 0, // NumChannels
      sampleRate & 0xFF, (sampleRate >> 8) & 0xFF, (sampleRate >> 16) & 0xFF,
      (sampleRate >> 24) & 0xFF,
      byteRate & 0xFF, (byteRate >> 8) & 0xFF, (byteRate >> 16) & 0xFF,
      (byteRate >> 24) & 0xFF,
      blockAlign, 0, // BlockAlign
      bitsPerSample, 0, // BitsPerSample
      // data subchunk
      0x64, 0x61, 0x74, 0x61, // "data"
      dataSize & 0xFF, (dataSize >> 8) & 0xFF, (dataSize >> 16) & 0xFF,
      (dataSize >> 24) & 0xFF,
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
