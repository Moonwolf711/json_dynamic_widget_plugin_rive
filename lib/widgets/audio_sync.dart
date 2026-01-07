// lib/widgets/audio_sync.dart
// Audio synchronization for animation timeline
// Works with just_audio, audioplayers, or any player that exposes position stream

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Abstract interface for audio player position sync
/// Implement this for your audio player of choice
abstract class AudioPositionProvider {
  /// Stream of current playback position
  Stream<Duration> get positionStream;

  /// Current position (for immediate reads)
  Duration get position;

  /// Whether audio is currently playing
  bool get isPlaying;

  /// Seek to position
  Future<void> seek(Duration position);

  /// Play
  Future<void> play();

  /// Pause
  Future<void> pause();

  /// Total duration (if known)
  Duration? get duration;
}

/// Sync controller that bridges audio player and animation timeline
class AudioSyncController extends ChangeNotifier {
  AudioPositionProvider? _audioProvider;
  StreamSubscription<Duration>? _positionSubscription;

  bool _isSyncEnabled = true;
  double _offsetSeconds = 0.0; // Audio offset from animation (can be negative)
  double _currentTime = 0.0;
  bool _isPlaying = false;

  // Callbacks for timeline control
  void Function(double time)? onSeek;
  void Function()? onPlay;
  void Function()? onPause;

  /// Current synced time in seconds
  double get currentTime => _currentTime;

  /// Whether sync is enabled
  bool get isSyncEnabled => _isSyncEnabled;

  /// Audio offset in seconds (positive = audio ahead, negative = audio behind)
  double get offsetSeconds => _offsetSeconds;

  /// Whether audio is playing
  bool get isPlaying => _isPlaying;

  /// Attach an audio provider
  void attachAudio(AudioPositionProvider provider) {
    detachAudio();
    _audioProvider = provider;

    _positionSubscription = provider.positionStream.listen((position) {
      if (_isSyncEnabled) {
        _currentTime = position.inMilliseconds / 1000.0 + _offsetSeconds;
        _isPlaying = provider.isPlaying;
        notifyListeners();
        onSeek?.call(_currentTime);
      }
    });
  }

  /// Detach audio provider
  void detachAudio() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _audioProvider = null;
  }

  /// Enable/disable sync
  void setSyncEnabled(bool enabled) {
    _isSyncEnabled = enabled;
    notifyListeners();
  }

  /// Set audio offset (in seconds)
  /// Positive = audio plays ahead of animation
  /// Negative = animation plays ahead of audio
  void setOffset(double seconds) {
    _offsetSeconds = seconds;
    notifyListeners();
  }

  /// Nudge offset by delta
  void nudgeOffset(double delta) {
    _offsetSeconds += delta;
    notifyListeners();
  }

  /// Seek both audio and animation to time
  Future<void> seekTo(double seconds) async {
    final audioTime = seconds - _offsetSeconds;
    if (_audioProvider != null && audioTime >= 0) {
      await _audioProvider!.seek(Duration(milliseconds: (audioTime * 1000).round()));
    }
    _currentTime = seconds;
    onSeek?.call(seconds);
    notifyListeners();
  }

  /// Play both audio and animation
  Future<void> play() async {
    await _audioProvider?.play();
    _isPlaying = true;
    onPlay?.call();
    notifyListeners();
  }

  /// Pause both audio and animation
  Future<void> pause() async {
    await _audioProvider?.pause();
    _isPlaying = false;
    onPause?.call();
    notifyListeners();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  void dispose() {
    detachAudio();
    super.dispose();
  }
}

/// Marker for sync points (e.g., beat markers, cue points)
class SyncMarker {
  final double time; // seconds
  final String label;
  final MarkerType type;

  const SyncMarker({
    required this.time,
    required this.label,
    this.type = MarkerType.cue,
  });

  Map<String, dynamic> toMap() => {
        'time': time,
        'label': label,
        'type': type.name,
      };

  factory SyncMarker.fromMap(Map<String, dynamic> map) => SyncMarker(
        time: (map['time'] as num).toDouble(),
        label: map['label'] as String,
        type: MarkerType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => MarkerType.cue,
        ),
      );
}

enum MarkerType {
  cue, // General cue point
  beat, // Beat/rhythm marker
  section, // Section marker (intro, verse, chorus)
  event, // Animation event trigger
}

/// Beat detection helper for automatic marker generation
class BeatDetector {
  final double bpm;
  final double startOffset; // When first beat occurs

  BeatDetector({
    required this.bpm,
    this.startOffset = 0.0,
  });

  /// Generate beat markers for a duration
  List<SyncMarker> generateBeats(Duration duration, {int subdivision = 1}) {
    final markers = <SyncMarker>[];
    final beatInterval = 60.0 / bpm / subdivision;
    final totalSeconds = duration.inMilliseconds / 1000.0;

    int beatNum = 0;
    for (double t = startOffset; t < totalSeconds; t += beatInterval) {
      final isDownbeat = beatNum % subdivision == 0;
      markers.add(SyncMarker(
        time: t,
        label: isDownbeat ? 'Beat ${beatNum ~/ subdivision + 1}' : '',
        type: isDownbeat ? MarkerType.beat : MarkerType.cue,
      ));
      beatNum++;
    }

    return markers;
  }

  /// Snap time to nearest beat
  double snapToBeat(double time, {int subdivision = 1}) {
    final beatInterval = 60.0 / bpm / subdivision;
    final beatsFromStart = ((time - startOffset) / beatInterval).round();
    return startOffset + beatsFromStart * beatInterval;
  }

  /// Get beat number at time
  int beatAt(double time, {int subdivision = 1}) {
    final beatInterval = 60.0 / bpm / subdivision;
    return ((time - startOffset) / beatInterval).floor();
  }
}

/// Example implementation for just_audio package
///
/// ```dart
/// import 'package:just_audio/just_audio.dart';
///
/// class JustAudioProvider implements AudioPositionProvider {
///   final AudioPlayer player;
///   JustAudioProvider(this.player);
///
///   @override
///   Stream<Duration> get positionStream => player.positionStream;
///
///   @override
///   Duration get position => player.position;
///
///   @override
///   bool get isPlaying => player.playing;
///
///   @override
///   Future<void> seek(Duration position) => player.seek(position);
///
///   @override
///   Future<void> play() => player.play();
///
///   @override
///   Future<void> pause() => player.pause();
///
///   @override
///   Duration? get duration => player.duration;
/// }
/// ```
