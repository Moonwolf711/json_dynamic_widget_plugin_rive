import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Animates a widget along a custom path
///
/// Purpose: Enables complex motion paths beyond simple linear movements
/// Use cases: Character movement, UI flourishes, guided tours
class AnimatedPath extends StatefulWidget {
  final Widget child;
  final Path path;
  final Duration duration;
  final Curve curve;
  final bool rotateAlongPath;
  final bool repeat;

  const AnimatedPath({
    super.key,
    required this.child,
    required this.path,
    this.duration = const Duration(seconds: 2),
    this.curve = Curves.easeInOut,
    this.rotateAlongPath = false,
    this.repeat = false,
  });

  @override
  State<AnimatedPath> createState() => _AnimatedPathState();
}

class _AnimatedPathState extends State<AnimatedPath>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ui.PathMetrics _pathMetrics;
  late ui.PathMetric _pathMetric;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    _pathMetrics = widget.path.computeMetrics();
    _pathMetric = _pathMetrics.first;

    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final distance = _animation.value * _pathMetric.length;
        final tangent = _pathMetric.getTangentForOffset(distance);

        if (tangent == null) return child ?? const SizedBox.shrink();

        final position = tangent.position;
        final angle = widget.rotateAlongPath ? tangent.angle : 0.0;

        return Transform(
          transform: Matrix4.identity()
            ..translate(position.dx, position.dy)
            ..rotateZ(angle),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
