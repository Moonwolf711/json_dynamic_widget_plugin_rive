// lib/widgets/animation_timeline.dart
import 'package:flutter/material.dart';
import '../math/bone.dart';
import '../math/transform.dart';

/// Represents a single keyframe in the animation
class Keyframe {
  final double time; // seconds
  final Map<String, Map<String, dynamic>> boneTransforms; // boneName -> transform data

  Keyframe(this.time, this.boneTransforms);

  Map<String, dynamic> toMap() => {
        'time': time,
        'bones': boneTransforms,
      };

  factory Keyframe.fromMap(Map<String, dynamic> map) => Keyframe(
        map['time'] as double,
        Map<String, Map<String, dynamic>>.from(map['bones'] as Map),
      );
}

/// Loop mode for animation playback
enum LoopMode { once, loop, pingPong }

/// Animation timeline widget - handles 20+ minute timelines efficiently
class AnimationTimeline extends StatefulWidget {
  final Duration duration;
  final List<Bone> bones;
  final void Function(double time)? onScrub;
  final void Function(List<Keyframe> keyframes)? onKeyframesChanged;
  final void Function(bool isPlaying)? onPlayStateChanged;
  final double pixelsPerSecond;
  final double fps;
  final List<Keyframe>? initialKeyframes;

  const AnimationTimeline({
    super.key,
    required this.duration,
    required this.bones,
    this.onScrub,
    this.onKeyframesChanged,
    this.onPlayStateChanged,
    this.pixelsPerSecond = 100,
    this.fps = 24,
    this.initialKeyframes,
  });

  @override
  State<AnimationTimeline> createState() => AnimationTimelineState();
}

class AnimationTimelineState extends State<AnimationTimeline>
    with TickerProviderStateMixin {
  late List<Keyframe> _keyframes;
  double _scrubPosition = 0.0; // in seconds
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  LoopMode _loopMode = LoopMode.once;
  bool _pingPongReverse = false;

  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  // Public getters
  double get currentTime => _scrubPosition;
  bool get isPlaying => _isPlaying;
  List<Keyframe> get keyframes => List.unmodifiable(_keyframes);

  @override
  void initState() {
    super.initState();
    _keyframes = widget.initialKeyframes?.toList() ?? [];

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )
      ..addListener(_onTick)
      ..addStatusListener(_onStatusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick() {
    final newTime = _controller.value * widget.duration.inSeconds;
    _updatePreview(newTime);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      switch (_loopMode) {
        case LoopMode.once:
          pause();
          break;
        case LoopMode.loop:
          _controller.forward(from: 0);
          break;
        case LoopMode.pingPong:
          _pingPongReverse = !_pingPongReverse;
          if (_pingPongReverse) {
            _controller.reverse(from: 1);
          } else {
            _controller.forward(from: 0);
          }
          break;
      }
    } else if (status == AnimationStatus.dismissed && _loopMode == LoopMode.pingPong) {
      _pingPongReverse = !_pingPongReverse;
      _controller.forward(from: 0);
    }
  }

  // ==================== PUBLIC API ====================

  /// Start or resume playback
  void play() {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    _controller.duration = Duration(
      milliseconds: (widget.duration.inMilliseconds / _playbackSpeed).round(),
    );
    _controller.forward(from: _scrubPosition / widget.duration.inSeconds);
    widget.onPlayStateChanged?.call(true);
  }

  /// Pause playback
  void pause() {
    if (!_isPlaying) return;
    setState(() => _isPlaying = false);
    _controller.stop();
    widget.onPlayStateChanged?.call(false);
  }

  /// Stop and reset to beginning
  void stop() {
    setState(() => _isPlaying = false);
    _controller.stop();
    _controller.reset();
    _pingPongReverse = false;
    _updatePreview(0);
    widget.onPlayStateChanged?.call(false);
  }

  /// Seek to specific time in seconds
  void seekTo(double seconds) {
    final clampedTime = seconds.clamp(0.0, widget.duration.inSeconds.toDouble());
    _controller.value = clampedTime / widget.duration.inSeconds;
    _updatePreview(clampedTime);
  }

  /// Step forward by one frame
  void stepForward() {
    final frameDuration = 1.0 / widget.fps;
    seekTo(_scrubPosition + frameDuration);
  }

  /// Step backward by one frame
  void stepBackward() {
    final frameDuration = 1.0 / widget.fps;
    seekTo(_scrubPosition - frameDuration);
  }

  /// Set playback speed (0.25 to 4.0)
  void setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed.clamp(0.25, 4.0);
    });
    if (_isPlaying) {
      final currentPos = _scrubPosition / widget.duration.inSeconds;
      _controller.duration = Duration(
        milliseconds: (widget.duration.inMilliseconds / _playbackSpeed).round(),
      );
      _controller.forward(from: currentPos);
    }
  }

  /// Set loop mode
  void setLoopMode(LoopMode mode) {
    setState(() {
      _loopMode = mode;
      _pingPongReverse = false;
    });
  }

  /// Add keyframe at current position
  void addKeyframe() => _addKeyframeAt(_scrubPosition);

  /// Remove keyframe near current position
  void removeKeyframe() => _removeKeyframeAt(_scrubPosition);

  /// Load keyframes from list
  void loadKeyframes(List<Keyframe> keyframes) {
    setState(() {
      _keyframes = keyframes.toList();
      _keyframes.sort((a, b) => a.time.compareTo(b.time));
    });
  }

  // ==================== INTERNAL ====================

  void _addKeyframeAt(double t) {
    final Map<String, Map<String, dynamic>> frame = {};

    for (final bone in widget.bones) {
      frame[bone.name] = bone.local.toMap();
    }

    setState(() {
      _keyframes.removeWhere((k) => (k.time - t).abs() < 0.001);
      _keyframes.add(Keyframe(t, frame));
      _keyframes.sort((a, b) => a.time.compareTo(b.time));
    });

    widget.onKeyframesChanged?.call(_keyframes);
  }

  void _removeKeyframeAt(double t) {
    setState(() {
      _keyframes.removeWhere((k) => (k.time - t).abs() < 0.1);
    });
    widget.onKeyframesChanged?.call(_keyframes);
  }

  void _updatePreview(double t) {
    setState(() {
      _scrubPosition = t.clamp(0, widget.duration.inSeconds.toDouble());
    });
    _applyKeyframes(t);
    widget.onScrub?.call(t);
  }

  void _applyKeyframes(double t) {
    if (_keyframes.isEmpty) return;

    Keyframe? prev;
    Keyframe? next;

    for (final keyframe in _keyframes) {
      if (keyframe.time <= t) {
        prev = keyframe;
      } else {
        next = keyframe;
        break;
      }
    }

    for (final bone in widget.bones) {
      Transform? startTransform;
      Transform? endTransform;
      double lerpT = 0;

      if (prev != null && prev.boneTransforms.containsKey(bone.name)) {
        startTransform = Transform.fromMap(prev.boneTransforms[bone.name]!);
      }

      if (next != null && next.boneTransforms.containsKey(bone.name)) {
        endTransform = Transform.fromMap(next.boneTransforms[bone.name]!);

        if (prev != null && next.time != prev.time) {
          lerpT = (t - prev.time) / (next.time - prev.time);
        }
      }

      if (startTransform != null && endTransform != null) {
        bone.local.setFrom(startTransform.lerp(endTransform, lerpT));
      } else if (startTransform != null) {
        bone.local.setFrom(startTransform);
      } else if (endTransform != null) {
        bone.local.setFrom(endTransform);
      }

      bone.update();
    }
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final frames = ((seconds % 1) * widget.fps).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}:${frames.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalPixels = widget.duration.inSeconds * widget.pixelsPerSecond;
    final maxSeconds = widget.duration.inSeconds.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transport controls row 1
        _buildTransportControls(),
        const SizedBox(height: 4),
        // Scrub slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(_formatTime(0), style: const TextStyle(fontSize: 10)),
              Expanded(
                child: Slider(
                  value: _scrubPosition,
                  min: 0,
                  max: maxSeconds,
                  onChanged: (v) => seekTo(v),
                  onChangeStart: (_) {
                    if (_isPlaying) pause();
                  },
                ),
              ),
              Text(_formatTime(maxSeconds), style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
        // Timeline canvas
        SizedBox(
          height: 80,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (_isPlaying) pause();
              final newTime = _scrubPosition + (details.delta.dx / widget.pixelsPerSecond);
              seekTo(newTime);
            },
            onTapDown: (details) {
              if (_isPlaying) pause();
              final scrollOffset = _scrollController.offset;
              final tapX = details.localPosition.dx + scrollOffset;
              final newTime = tapX / widget.pixelsPerSecond;
              seekTo(newTime);
            },
            onDoubleTap: () => _addKeyframeAt(_scrubPosition),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalPixels,
                height: 80,
                child: CustomPaint(
                  painter: _TimelinePainter(
                    pixelsPerSecond: widget.pixelsPerSecond,
                    totalSeconds: maxSeconds,
                    scrubPosition: _scrubPosition,
                    keyframes: _keyframes,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Step back
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 20),
          tooltip: 'Previous frame',
          onPressed: stepBackward,
        ),
        // Stop
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: stop,
        ),
        // Play/Pause
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
          onPressed: _isPlaying ? pause : play,
        ),
        // Step forward
        IconButton(
          icon: const Icon(Icons.skip_next, size: 20),
          tooltip: 'Next frame',
          onPressed: stepForward,
        ),
        const SizedBox(width: 8),
        // Timecode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatTime(_scrubPosition),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Speed dropdown
        DropdownButton<double>(
          value: _playbackSpeed,
          isDense: true,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 0.25, child: Text('0.25x')),
            DropdownMenuItem(value: 0.5, child: Text('0.5x')),
            DropdownMenuItem(value: 1.0, child: Text('1x')),
            DropdownMenuItem(value: 2.0, child: Text('2x')),
            DropdownMenuItem(value: 4.0, child: Text('4x')),
          ],
          onChanged: (v) => setSpeed(v ?? 1.0),
        ),
        const SizedBox(width: 8),
        // Loop mode
        PopupMenuButton<LoopMode>(
          icon: Icon(
            _loopMode == LoopMode.once
                ? Icons.arrow_right_alt
                : _loopMode == LoopMode.loop
                    ? Icons.repeat
                    : Icons.swap_horiz,
            size: 20,
          ),
          tooltip: 'Loop mode',
          onSelected: setLoopMode,
          itemBuilder: (context) => [
            const PopupMenuItem(value: LoopMode.once, child: Text('Play once')),
            const PopupMenuItem(value: LoopMode.loop, child: Text('Loop')),
            const PopupMenuItem(value: LoopMode.pingPong, child: Text('Ping-pong')),
          ],
        ),
        const SizedBox(width: 8),
        // Keyframe buttons
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          tooltip: 'Add keyframe',
          onPressed: addKeyframe,
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          tooltip: 'Remove keyframe',
          onPressed: removeKeyframe,
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double pixelsPerSecond;
  final double totalSeconds;
  final double scrubPosition;
  final List<Keyframe> keyframes;

  _TimelinePainter({
    required this.pixelsPerSecond,
    required this.totalSeconds,
    required this.scrubPosition,
    required this.keyframes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF2D2D2D);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (double t = 0; t <= totalSeconds; t += 1) {
      final x = t * pixelsPerSecond;
      final isMajor = t % 10 == 0;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, isMajor ? 16 : 8),
        isMajor ? majorTickPaint : tickPaint,
      );

      if (isMajor) {
        final mins = (t / 60).floor();
        final secs = (t % 60).floor();
        textPainter.text = TextSpan(
          text: '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + 2, 2));
      }
    }

    // Keyframes
    final keyframePaint = Paint()..color = Colors.amber;
    for (final keyframe in keyframes) {
      final x = keyframe.time * pixelsPerSecond;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, size.height / 2 + 8), width: 6, height: 30),
          const Radius.circular(2),
        ),
        keyframePaint,
      );
    }

    // Playhead
    final playheadX = scrubPosition * pixelsPerSecond;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2,
    );

    final handlePath = Path()
      ..moveTo(playheadX - 5, 0)
      ..lineTo(playheadX + 5, 0)
      ..lineTo(playheadX, 8)
      ..close();
    canvas.drawPath(handlePath, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      scrubPosition != old.scrubPosition || keyframes.length != old.keyframes.length;
}
