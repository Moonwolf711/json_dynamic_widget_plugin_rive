/// WFL Character Animations using simple_animations package
/// Provides MovieTween definitions for organic, multi-property character idle animations
library;

import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

/// Terry's idle animation - energetic, faster movements
/// Use with MirrorAnimationBuilder for continuous looping
final terryIdleTween = MovieTween()
  // Breathing - subtle up/down (3 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 3000))
      .tween('breathY', Tween<double>(begin: 0.0, end: 2.0),
          curve: Curves.easeInOut)
  // Eye wander X - slow drift (4 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 4000))
      .tween('eyeX', Tween<double>(begin: -2.5, end: 2.5),
          curve: Curves.easeInOut)
  // Eye wander Y - slower (5 second cycle, offset start for organic feel)
  ..scene(
          begin: const Duration(milliseconds: 500),
          duration: const Duration(milliseconds: 5000))
      .tween('eyeY', Tween<double>(begin: -1.5, end: 1.5),
          curve: Curves.easeInOut)
  // Head bob - energetic (800ms cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 800))
      .tween('headBob', Tween<double>(begin: 0.0, end: 3.0),
          curve: Curves.easeInOut)
  // Body sway - natural weight shift (2.5 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 2500))
      .tween('sway', Tween<double>(begin: -3.5, end: 3.5),
          curve: Curves.easeInOut)
  // Lean - very slow rotation (6 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 6000))
      .tween('lean', Tween<double>(begin: -1.8, end: 1.8),
          curve: Curves.easeInOut);

/// Nigel's idle animation - chill, slower movements
/// Use with MirrorAnimationBuilder for continuous looping
final nigelIdleTween = MovieTween()
  // Breathing - deeper, slower (4 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 4000))
      .tween('breathY', Tween<double>(begin: 0.0, end: 2.5),
          curve: Curves.easeInOut)
  // Eye wander X - lazy drift (5 second cycle)
  ..scene(
          begin: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 5000))
      .tween('eyeX', Tween<double>(begin: -2.0, end: 2.0),
          curve: Curves.easeInOut)
  // Eye wander Y - even slower (6 second cycle)
  ..scene(
          begin: const Duration(milliseconds: 800),
          duration: const Duration(milliseconds: 6000))
      .tween('eyeY', Tween<double>(begin: -1.2, end: 1.2),
          curve: Curves.easeInOut)
  // Head bob - chill (1.2 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 1200))
      .tween('headBob', Tween<double>(begin: 0.0, end: 2.0),
          curve: Curves.easeInOut)
  // Body sway - relaxed (3.5 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 3500))
      .tween('sway', Tween<double>(begin: -2.8, end: 2.8),
          curve: Curves.easeInOut)
  // Lean - glacial rotation (8 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 8000))
      .tween('lean', Tween<double>(begin: -1.5, end: 1.5),
          curve: Curves.easeInOut);

/// Button glow animation for UI elements
final buttonGlowTween = MovieTween()
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 2500))
      .tween('glow', Tween<double>(begin: 0.3, end: 0.7),
          curve: Curves.easeInOut);

// ==================== LAYER-SPECIFIC STATE MACHINES ====================
// Each layer gets its own independent animation for more organic movement

/// Terry's BODY layer animation - breathing, sway, lean
final terryBodyTween = MovieTween()
  // Breathing - subtle up/down (3 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 3000))
      .tween('breathY', Tween<double>(begin: 0.0, end: 2.0),
          curve: Curves.easeInOut)
  // Body sway - natural weight shift (2.5 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 2500))
      .tween('sway', Tween<double>(begin: -3.5, end: 3.5),
          curve: Curves.easeInOut)
  // Lean - very slow rotation (6 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 6000))
      .tween('lean', Tween<double>(begin: -1.8, end: 1.8),
          curve: Curves.easeInOut);

/// Terry's EYES layer animation - wander, blink emphasis
final terryEyesTween = MovieTween()
  // Eye wander X - slow drift (4 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 4000))
      .tween('eyeX', Tween<double>(begin: -2.5, end: 2.5),
          curve: Curves.easeInOut)
  // Eye wander Y - slower (5 second cycle, offset start for organic feel)
  ..scene(
          begin: const Duration(milliseconds: 500),
          duration: const Duration(milliseconds: 5000))
      .tween('eyeY', Tween<double>(begin: -1.5, end: 1.5),
          curve: Curves.easeInOut)
  // Subtle vertical "focus" shift (2 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 2000))
      .tween('focus', Tween<double>(begin: 0.0, end: 0.5),
          curve: Curves.easeInOut);

/// Terry's MOUTH layer animation - subtle movement when not talking
final terryMouthTween = MovieTween()
  // Slight horizontal shift (3 second cycle - like subtle expression change)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 3000))
      .tween('mouthX', Tween<double>(begin: -0.5, end: 0.5),
          curve: Curves.easeInOut)
  // Vertical micro-movement (1.5 second cycle - breathing effect on mouth)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 1500))
      .tween('mouthY', Tween<double>(begin: 0.0, end: 0.8),
          curve: Curves.easeInOut);

/// Nigel's BODY layer animation - chill breathing, lazy sway
final nigelBodyTween = MovieTween()
  // Breathing - deeper, slower (4 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 4000))
      .tween('breathY', Tween<double>(begin: 0.0, end: 2.5),
          curve: Curves.easeInOut)
  // Body sway - relaxed (3.5 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 3500))
      .tween('sway', Tween<double>(begin: -2.8, end: 2.8),
          curve: Curves.easeInOut)
  // Lean - glacial rotation (8 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 8000))
      .tween('lean', Tween<double>(begin: -1.5, end: 1.5),
          curve: Curves.easeInOut);

/// Nigel's EYES layer animation - lazy wandering
final nigelEyesTween = MovieTween()
  // Eye wander X - lazy drift (5 second cycle)
  ..scene(
          begin: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 5000))
      .tween('eyeX', Tween<double>(begin: -2.0, end: 2.0),
          curve: Curves.easeInOut)
  // Eye wander Y - even slower (6 second cycle)
  ..scene(
          begin: const Duration(milliseconds: 800),
          duration: const Duration(milliseconds: 6000))
      .tween('eyeY', Tween<double>(begin: -1.2, end: 1.2),
          curve: Curves.easeInOut)
  // Subtle vertical "focus" shift (3 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 3000))
      .tween('focus', Tween<double>(begin: 0.0, end: 0.3),
          curve: Curves.easeInOut);

/// Nigel's MOUTH layer animation - chill expression shifts
final nigelMouthTween = MovieTween()
  // Slight horizontal shift (4 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 4000))
      .tween('mouthX', Tween<double>(begin: -0.3, end: 0.3),
          curve: Curves.easeInOut)
  // Vertical micro-movement (2 second cycle)
  ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 2000))
      .tween('mouthY', Tween<double>(begin: 0.0, end: 0.5),
          curve: Curves.easeInOut);

/// Get the longest duration from a character's MovieTween (for MirrorAnimationBuilder)
Duration getTweenDuration(MovieTween tween) => tween.duration;

/// Helper widget that wraps a character in MirrorAnimationBuilder
/// Applies Transform with breathing, sway, headBob, and lean
class AnimatedCharacterWrapper extends StatelessWidget {
  final Widget child;
  final MovieTween tween;
  final double eyeXMultiplier;
  final double eyeYMultiplier;

  const AnimatedCharacterWrapper({
    super.key,
    required this.child,
    required this.tween,
    this.eyeXMultiplier = 1.0,
    this.eyeYMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return MirrorAnimationBuilder<Movie>(
      tween: tween,
      duration: tween.duration,
      builder: (context, value, child) {
        final breathY = value.get<double>('breathY');
        final headBob = value.get<double>('headBob');
        final sway = value.get<double>('sway');
        final lean = value.get<double>('lean');

        return Transform(
          transform: Matrix4.identity()
            ..translate(sway, breathY + headBob)
            ..rotateZ(lean * 0.01),
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Extract animation values from a Movie for manual use
class AnimationValues {
  final double breathY;
  final double eyeX;
  final double eyeY;
  final double headBob;
  final double sway;
  final double lean;

  const AnimationValues({
    this.breathY = 0,
    this.eyeX = 0,
    this.eyeY = 0,
    this.headBob = 0,
    this.sway = 0,
    this.lean = 0,
  });

  factory AnimationValues.fromMovie(Movie movie) {
    return AnimationValues(
      breathY: movie.get<double>('breathY'),
      eyeX: movie.get<double>('eyeX'),
      eyeY: movie.get<double>('eyeY'),
      headBob: movie.get<double>('headBob'),
      sway: movie.get<double>('sway'),
      lean: movie.get<double>('lean'),
    );
  }
}
