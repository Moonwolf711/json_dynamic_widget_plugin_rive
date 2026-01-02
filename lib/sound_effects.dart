import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound Effects Manager for WFL Show Mode
/// Plays comedy sound effects after jokes and reactions
/// NOTE: audioplayers has a threading bug on Windows that causes crashes.
/// Background music and sound effects are disabled on Windows for stability.
class SoundEffects {
  static final SoundEffects _instance = SoundEffects._internal();
  factory SoundEffects() => _instance;
  SoundEffects._internal();

  // Check if we're on Windows - audioplayers crashes on Windows due to threading bug
  static final bool _isWindows = Platform.isWindows;

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _bgPlayer = AudioPlayer();  // Dedicated background music player
  final Random _random = Random();
  bool _enabled = true;
  double _volume = 0.7;
  double _bgVolume = 0.3;  // Background music is quieter
  bool _bgPlaying = false;

  /// Sound effect types
  static const String rimshot = 'rimshot';
  static const String sadTrombone = 'sad_trombone';
  static const String airhorn = 'airhorn';
  static const String laughTrack = 'laugh_track';
  static const String drumroll = 'drumroll';
  static const String whoosh = 'whoosh';
  static const String ding = 'ding';
  static const String buzzer = 'buzzer';

  /// Map of effect names to asset paths
  static const Map<String, String> _effectPaths = {
    rimshot: 'assets/sfx/rimshot.mp3',
    sadTrombone: 'assets/sfx/sad_trombone.mp3',
    airhorn: 'assets/sfx/airhorn.mp3',
    laughTrack: 'assets/sfx/laugh_track.mp3',
    drumroll: 'assets/sfx/drumroll.mp3',
    whoosh: 'assets/sfx/whoosh.mp3',
    ding: 'assets/sfx/ding.mp3',
    buzzer: 'assets/sfx/buzzer.mp3',
  };

  /// Background music tracks (from Suno AI)
  static const List<String> _backgroundTracks = [
    'assets/sfx/background/rimshot_bg.mp3',
    'assets/sfx/background/sad_trombone_bg.mp3',
    'assets/sfx/background/airhorn_bg.mp3',
    'assets/sfx/background/laugh_track_bg.mp3',
    'assets/sfx/background/drumroll_bg.mp3',
    'assets/sfx/background/whoosh_bg.mp3',
  ];

  /// Enable/disable sound effects
  bool get enabled => _enabled;
  set enabled(bool value) => _enabled = value;

  /// Volume control (0.0 to 1.0)
  double get volume => _volume;
  set volume(double value) => _volume = value.clamp(0.0, 1.0);

  /// Background music volume (0.0 to 1.0)
  double get bgVolume => _bgVolume;
  set bgVolume(double value) {
    _bgVolume = value.clamp(0.0, 1.0);
    _bgPlayer.setVolume(_bgVolume);
  }

  /// Check if background music is playing
  bool get isBgPlaying => _bgPlaying;

  /// Start background music (plays random track, loops)
  Future<void> startBackgroundMusic() async {
    // Skip on Windows due to audioplayers threading bug
    if (_isWindows) {
      debugPrint('SoundEffects: Background music disabled on Windows (audioplayers threading bug)');
      return;
    }
    if (_bgPlaying) return;  // Already playing

    try {
      // Pick a random background track
      final track = _backgroundTracks[_random.nextInt(_backgroundTracks.length)];
      debugPrint('SoundEffects: Starting background music: $track');

      await _bgPlayer.setVolume(_bgVolume);
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);  // Loop the track
      await _bgPlayer.play(AssetSource(track.replaceFirst('assets/', '')));
      _bgPlaying = true;

      debugPrint('SoundEffects: Background music started');
    } catch (e) {
      debugPrint('SoundEffects: Failed to start background music - $e');
    }
  }

  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    if (!_bgPlaying) return;

    try {
      await _bgPlayer.stop();
      _bgPlaying = false;
      debugPrint('SoundEffects: Background music stopped');
    } catch (e) {
      debugPrint('SoundEffects: Failed to stop background music - $e');
    }
  }

  /// Pause background music
  Future<void> pauseBackgroundMusic() async {
    if (!_bgPlaying) return;
    await _bgPlayer.pause();
  }

  /// Resume background music
  Future<void> resumeBackgroundMusic() async {
    if (!_bgPlaying) return;
    await _bgPlayer.resume();
  }

  /// Play a specific sound effect
  Future<void> play(String effect) async {
    // Skip on Windows due to audioplayers threading bug
    if (_isWindows) return;
    if (!_enabled) return;

    final path = _effectPaths[effect];
    if (path == null) {
      debugPrint('SoundEffects: Unknown effect "$effect"');
      return;
    }

    try {
      await _player.setVolume(_volume);
      await _player.play(AssetSource(path.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('SoundEffects: Failed to play $effect - $e');
    }
  }

  /// Play rimshot after a good joke
  Future<void> playRimshot() => play(rimshot);

  /// Play sad trombone after a bad joke or fail
  Future<void> playSadTrombone() => play(sadTrombone);

  /// Play airhorn for hype moments
  Future<void> playAirhorn() => play(airhorn);

  /// Play laugh track after funny moment
  Future<void> playLaughTrack() => play(laughTrack);

  /// Play a random comedy effect
  Future<void> playRandomComedy() async {
    final effects = [rimshot, laughTrack, airhorn];
    final effect = effects[_random.nextInt(effects.length)];
    await play(effect);
  }

  /// Play effect based on joke quality/content
  /// Analyzes the roast text to pick appropriate sound
  Future<void> playForRoast(String roastText) async {
    if (!_enabled) return;

    final text = roastText.toLowerCase();

    // Detect mood from text
    if (text.contains('bruh') ||
        text.contains('wild') ||
        text.contains('lessgo') ||
        text.contains('fire')) {
      // Terry-style hype -> airhorn or rimshot
      await play(_random.nextBool() ? airhorn : rimshot);
    } else if (text.contains('dreadful') ||
        text.contains('rather') ||
        text.contains('indeed') ||
        text.contains('curious')) {
      // Nigel-style dry wit -> rimshot or laugh track
      await play(_random.nextBool() ? rimshot : laughTrack);
    } else if (text.contains('fail') ||
        text.contains('bad') ||
        text.contains('terrible')) {
      // Negative reaction -> sad trombone
      await play(sadTrombone);
    } else {
      // Default -> random comedy effect
      await playRandomComedy();
    }
  }

  /// Dispose all players
  void dispose() {
    _player.dispose();
    _bgPlayer.dispose();
  }
}

/// Extension to easily trigger sound effects from anywhere
extension SoundEffectsExtension on String {
  /// Play this string as a sound effect
  Future<void> playSfx() => SoundEffects().play(this);
}
