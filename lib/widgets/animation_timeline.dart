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

/// Animation timeline widget - handles 20+ minute timelines efficiently
class AnimationTimeline extends StatefulWidget {
  final Duration duration;
  final List<Bone> bones;
  final void Function(double time)? onScrub;
  final void Function(List<Keyframe> keyframes)? onKeyframesChanged;
  final double pixelsPerSecond;
  final double fps;

  const AnimationTimeline({
    super.key,
    required this.duration,
    required this.bones,
    this.onScrub,
    this.onKeyframesChanged,
    this.pixelsPerSecond = 100,
    this.fps = 24,
  });

  @override
  State<AnimationTimeline> createState() => _AnimationTimelineState();
}

class _AnimationTimelineState extends State<AnimationTimeline>
    with SingleTickerProviderStateMixin {
  final List<Keyframe> _keyframes = [];
  double _scrubPosition = 0.0; // in seconds
  bool _isPlaying = false;
  late AnimationController _playbackController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _playbackController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_onPlaybackTick);
  }

  @override
  void dispose() {
    _playbackController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPlaybackTick() {
    if (_isPlaying) {
      final newTime = _playbackController.value * widget.duration.inSeconds;
      _updatePreview(newTime);
    }
  }

  void _addKeyframeAt(double t) {
    final Map<String, Map<String, dynamic>> frame = {};

    for (final bone in widget.bones) {
      frame[bone.name] = bone.local.toMap();
    }

    setState(() {
      // Remove existing keyframe at same time (within tolerance)
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

    // Find surrounding keyframes for interpolation
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

    // Apply interpolated transforms to bones
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

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackController.forward(from: _scrubPosition / widget.duration.inSeconds);
      } else {
        _playbackController.stop();
      }
    });
  }

  void _stopPlayback() {
    setState(() {
      _isPlaying = false;
      _playbackController.stop();
      _playbackController.reset();
      _updatePreview(0);
    });
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transport controls
        _buildTransportControls(),
        const SizedBox(height: 8),
        // Timeline
        SizedBox(
          height: 100,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final newTime = _scrubPosition +
                  (details.delta.dx / widget.pixelsPerSecond);
              _updatePreview(newTime);
            },
            onTapDown: (details) {
              final scrollOffset = _scrollController.offset;
              final tapX = details.localPosition.dx + scrollOffset;
              final newTime = tapX / widget.pixelsPerSecond;
              _updatePreview(newTime);
            },
            onDoubleTapDown: (details) {
              _addKeyframeAt(_scrubPosition);
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalPixels,
                height: 100,
                child: CustomPaint(
                  painter: _TimelinePainter(
                    pixelsPerSecond: widget.pixelsPerSecond,
                    totalSeconds: widget.duration.inSeconds.toDouble(),
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
        // Stop button
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: _stopPlayback,
        ),
        // Play/Pause button
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _togglePlayback,
        ),
        // Time display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatTime(_scrubPosition),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Add keyframe button
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add keyframe (or double-tap timeline)',
          onPressed: () => _addKeyframeAt(_scrubPosition),
        ),
        // Remove keyframe button
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove keyframe at current position',
          onPressed: () => _removeKeyframeAt(_scrubPosition),
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

    // Draw second markers
    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (double t = 0; t <= totalSeconds; t += 1) {
      final x = t * pixelsPerSecond;
      final isMajor = t % 10 == 0;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, isMajor ? 20 : 10),
        isMajor ? majorTickPaint : tickPaint,
      );

      // Draw time label every 10 seconds
      if (isMajor) {
        final mins = (t / 60).floor();
        final secs = (t % 60).floor();
        textPainter.text = TextSpan(
          text: '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + 4, 4));
      }
    }

    // Draw keyframe markers
    final keyframePaint = Paint()..color = Colors.amber;
    for (final keyframe in keyframes) {
      final x = keyframe.time * pixelsPerSecond;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, size.height / 2), width: 8, height: 40),
          const Radius.circular(2),
        ),
        keyframePaint,
      );
    }

    // Draw playhead
    final playheadPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    final playheadX = scrubPosition * pixelsPerSecond;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    // Draw playhead handle
    final handlePath = Path()
      ..moveTo(playheadX - 6, 0)
      ..lineTo(playheadX + 6, 0)
      ..lineTo(playheadX, 10)
      ..close();
    canvas.drawPath(handlePath, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      scrubPosition != old.scrubPosition ||
      keyframes.length != old.keyframes.length;
}
