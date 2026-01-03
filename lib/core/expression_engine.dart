// expression_engine.dart
// WFL Proprietary Expression Engine v1.0
// Copyright (c) 2024 Wooking For Love Project - All Rights Reserved
// Original implementation - no third-party code dependencies
//
// Advanced procedural facial animation system with:
// - 27-point expression mapping
// - Micro-expression layering
// - Emotional state blending
// - Pupil reactivity
// - Asymmetric expression support

import 'dart:math' as math;

/// Core expression point - represents a controllable facial feature
class ExpressionPoint {
  final String id;
  double value;           // -1.0 to 1.0 normalized
  double velocity;        // rate of change
  double tension;         // spring tension for procedural motion
  double damping;         // damping factor

  ExpressionPoint({
    required this.id,
    this.value = 0.0,
    this.velocity = 0.0,
    this.tension = 0.8,
    this.damping = 0.3,
  });

  /// Spring-based interpolation toward target
  void springTo(double target, double dt) {
    final force = (target - value) * tension;
    velocity += force * dt;
    velocity *= (1.0 - damping);
    value += velocity * dt;
    value = value.clamp(-1.0, 1.0);
  }

  /// Instant set (for keyframed animation)
  void set(double v) {
    value = v.clamp(-1.0, 1.0);
    velocity = 0.0;
  }

  /// Add noise for organic feel
  void addNoise(double amplitude, double seed) {
    final noise = math.sin(seed * 17.3) * math.cos(seed * 23.7) * amplitude;
    value = (value + noise).clamp(-1.0, 1.0);
  }
}

/// 27-point expression rig
class ExpressionRig {
  // Eyebrows (6 points)
  late final ExpressionPoint browLeftInner;
  late final ExpressionPoint browLeftMid;
  late final ExpressionPoint browLeftOuter;
  late final ExpressionPoint browRightInner;
  late final ExpressionPoint browRightMid;
  late final ExpressionPoint browRightOuter;

  // Eyelids (4 points)
  late final ExpressionPoint lidLeftUpper;
  late final ExpressionPoint lidLeftLower;
  late final ExpressionPoint lidRightUpper;
  late final ExpressionPoint lidRightLower;

  // Pupils (4 points - position + dilation)
  late final ExpressionPoint pupilLeftX;
  late final ExpressionPoint pupilLeftY;
  late final ExpressionPoint pupilRightX;
  late final ExpressionPoint pupilRightY;
  late final ExpressionPoint pupilDilation;  // shared

  // Cheeks (2 points)
  late final ExpressionPoint cheekLeft;
  late final ExpressionPoint cheekRight;

  // Nose (2 points)
  late final ExpressionPoint nostrilLeft;
  late final ExpressionPoint nostrilRight;

  // Mouth handled separately by viseme system
  // But we add corner overrides for expressions
  late final ExpressionPoint mouthCornerLeft;
  late final ExpressionPoint mouthCornerRight;
  late final ExpressionPoint mouthStretch;

  // Head orientation (3 points)
  late final ExpressionPoint headYaw;
  late final ExpressionPoint headPitch;
  late final ExpressionPoint headRoll;

  // All points for batch operations
  late final List<ExpressionPoint> allPoints;

  ExpressionRig() {
    browLeftInner = ExpressionPoint(id: 'brow_l_in');
    browLeftMid = ExpressionPoint(id: 'brow_l_mid');
    browLeftOuter = ExpressionPoint(id: 'brow_l_out');
    browRightInner = ExpressionPoint(id: 'brow_r_in');
    browRightMid = ExpressionPoint(id: 'brow_r_mid');
    browRightOuter = ExpressionPoint(id: 'brow_r_out');

    lidLeftUpper = ExpressionPoint(id: 'lid_l_up');
    lidLeftLower = ExpressionPoint(id: 'lid_l_low');
    lidRightUpper = ExpressionPoint(id: 'lid_r_up');
    lidRightLower = ExpressionPoint(id: 'lid_r_low');

    pupilLeftX = ExpressionPoint(id: 'pupil_l_x');
    pupilLeftY = ExpressionPoint(id: 'pupil_l_y');
    pupilRightX = ExpressionPoint(id: 'pupil_r_x');
    pupilRightY = ExpressionPoint(id: 'pupil_r_y');
    pupilDilation = ExpressionPoint(id: 'pupil_dil');

    cheekLeft = ExpressionPoint(id: 'cheek_l');
    cheekRight = ExpressionPoint(id: 'cheek_r');

    nostrilLeft = ExpressionPoint(id: 'nostril_l');
    nostrilRight = ExpressionPoint(id: 'nostril_r');

    mouthCornerLeft = ExpressionPoint(id: 'mouth_l');
    mouthCornerRight = ExpressionPoint(id: 'mouth_r');
    mouthStretch = ExpressionPoint(id: 'mouth_stretch');

    headYaw = ExpressionPoint(id: 'head_yaw', tension: 0.5, damping: 0.4);
    headPitch = ExpressionPoint(id: 'head_pitch', tension: 0.5, damping: 0.4);
    headRoll = ExpressionPoint(id: 'head_roll', tension: 0.6, damping: 0.35);

    allPoints = [
      browLeftInner, browLeftMid, browLeftOuter,
      browRightInner, browRightMid, browRightOuter,
      lidLeftUpper, lidLeftLower, lidRightUpper, lidRightLower,
      pupilLeftX, pupilLeftY, pupilRightX, pupilRightY, pupilDilation,
      cheekLeft, cheekRight,
      nostrilLeft, nostrilRight,
      mouthCornerLeft, mouthCornerRight, mouthStretch,
      headYaw, headPitch, headRoll,
    ];
  }

  /// Reset all points to neutral
  void reset() {
    for (final p in allPoints) {
      p.value = 0.0;
      p.velocity = 0.0;
    }
  }

  /// Update all springs (call every frame)
  void tick(double dt) {
    for (final p in allPoints) {
      // Apply micro-damping
      p.velocity *= 0.98;
    }
  }

  /// Export current state as map
  Map<String, double> export() {
    return {for (final p in allPoints) p.id: p.value};
  }

  /// Import state from map
  void import(Map<String, double> data) {
    for (final p in allPoints) {
      if (data.containsKey(p.id)) {
        p.set(data[p.id]!);
      }
    }
  }
}

/// Named expression presets
class ExpressionPreset {
  final String name;
  final Map<String, double> targets;
  final double transitionSpeed;

  const ExpressionPreset({
    required this.name,
    required this.targets,
    this.transitionSpeed = 1.0,
  });
}

/// Built-in expression library - ORIGINAL DESIGNS
class ExpressionLibrary {
  static const neutral = ExpressionPreset(
    name: 'neutral',
    targets: {},  // all zeros
    transitionSpeed: 0.8,
  );

  static const happy = ExpressionPreset(
    name: 'happy',
    targets: {
      'brow_l_mid': 0.2, 'brow_r_mid': 0.2,
      'cheek_l': 0.6, 'cheek_r': 0.6,
      'mouth_l': 0.4, 'mouth_r': 0.4,
      'lid_l_low': 0.2, 'lid_r_low': 0.2,  // slight squint
    },
    transitionSpeed: 1.2,
  );

  static const excited = ExpressionPreset(
    name: 'excited',
    targets: {
      'brow_l_in': 0.6, 'brow_l_mid': 0.8, 'brow_l_out': 0.5,
      'brow_r_in': 0.6, 'brow_r_mid': 0.8, 'brow_r_out': 0.5,
      'lid_l_up': 0.4, 'lid_r_up': 0.4,  // wide eyes
      'pupil_dil': 0.3,
      'cheek_l': 0.4, 'cheek_r': 0.4,
      'mouth_l': 0.5, 'mouth_r': 0.5,
    },
    transitionSpeed: 1.5,
  );

  static const suspicious = ExpressionPreset(
    name: 'suspicious',
    targets: {
      'brow_l_in': 0.4, 'brow_l_out': -0.3,  // asymmetric
      'brow_r_in': -0.2, 'brow_r_out': 0.5,
      'lid_l_up': -0.3, 'lid_r_up': 0.1,  // one eye narrowed
      'pupil_l_x': 0.2, 'pupil_r_x': 0.2,  // side glance
      'mouth_l': -0.2, 'mouth_r': 0.1,
      'head_yaw': 0.15,
    },
    transitionSpeed: 0.7,
  );

  static const angry = ExpressionPreset(
    name: 'angry',
    targets: {
      'brow_l_in': -0.7, 'brow_l_mid': -0.4, 'brow_l_out': -0.2,
      'brow_r_in': -0.7, 'brow_r_mid': -0.4, 'brow_r_out': -0.2,
      'lid_l_up': -0.2, 'lid_r_up': -0.2,
      'nostril_l': 0.4, 'nostril_r': 0.4,
      'mouth_stretch': 0.3,
      'head_pitch': -0.1,
    },
    transitionSpeed: 1.0,
  );

  static const sad = ExpressionPreset(
    name: 'sad',
    targets: {
      'brow_l_in': 0.5, 'brow_l_out': -0.4,
      'brow_r_in': 0.5, 'brow_r_out': -0.4,
      'lid_l_up': -0.3, 'lid_r_up': -0.3,
      'cheek_l': -0.2, 'cheek_r': -0.2,
      'mouth_l': -0.4, 'mouth_r': -0.4,
      'head_pitch': 0.15,
    },
    transitionSpeed: 0.5,
  );

  static const curious = ExpressionPreset(
    name: 'curious',
    targets: {
      'brow_l_mid': 0.5, 'brow_r_mid': 0.5,
      'brow_l_out': 0.3, 'brow_r_out': 0.3,
      'lid_l_up': 0.2, 'lid_r_up': 0.2,
      'pupil_dil': 0.2,
      'head_pitch': -0.1,
      'head_roll': 0.08,
    },
    transitionSpeed: 1.0,
  );

  static const laughing = ExpressionPreset(
    name: 'laughing',
    targets: {
      'brow_l_mid': 0.3, 'brow_r_mid': 0.3,
      'lid_l_up': -0.5, 'lid_l_low': 0.4,  // squinted shut
      'lid_r_up': -0.5, 'lid_r_low': 0.4,
      'cheek_l': 0.8, 'cheek_r': 0.8,
      'mouth_l': 0.6, 'mouth_r': 0.6,
      'mouth_stretch': 0.5,
      'nostril_l': 0.2, 'nostril_r': 0.2,
    },
    transitionSpeed: 1.3,
  );

  static const smirk = ExpressionPreset(
    name: 'smirk',
    targets: {
      'brow_l_out': 0.3,
      'brow_r_in': 0.1, 'brow_r_out': -0.1,
      'lid_l_up': -0.1, 'lid_r_up': -0.2,
      'cheek_r': 0.3,
      'mouth_l': 0.0, 'mouth_r': 0.5,  // one-sided smile
      'head_yaw': -0.1,
    },
    transitionSpeed: 0.8,
  );

  static const shocked = ExpressionPreset(
    name: 'shocked',
    targets: {
      'brow_l_in': 0.8, 'brow_l_mid': 0.9, 'brow_l_out': 0.7,
      'brow_r_in': 0.8, 'brow_r_mid': 0.9, 'brow_r_out': 0.7,
      'lid_l_up': 0.7, 'lid_r_up': 0.7,
      'pupil_dil': 0.5,
      'mouth_stretch': -0.3,  // jaw drop
    },
    transitionSpeed: 2.0,
  );

  static const sleepy = ExpressionPreset(
    name: 'sleepy',
    targets: {
      'brow_l_mid': -0.2, 'brow_r_mid': -0.2,
      'lid_l_up': -0.6, 'lid_r_up': -0.6,
      'cheek_l': -0.1, 'cheek_r': -0.1,
      'mouth_l': -0.1, 'mouth_r': -0.1,
      'head_pitch': 0.2,
    },
    transitionSpeed: 0.3,
  );

  static const flirty = ExpressionPreset(
    name: 'flirty',
    targets: {
      'brow_l_mid': 0.3, 'brow_r_mid': 0.4,
      'lid_l_up': -0.2, 'lid_r_up': -0.3,
      'lid_l_low': 0.1, 'lid_r_low': 0.15,
      'cheek_l': 0.2, 'cheek_r': 0.3,
      'mouth_l': 0.2, 'mouth_r': 0.35,
      'head_roll': -0.1,
      'head_yaw': 0.08,
    },
    transitionSpeed: 0.6,
  );

  static const disgusted = ExpressionPreset(
    name: 'disgusted',
    targets: {
      'brow_l_in': -0.3, 'brow_r_in': -0.3,
      'lid_l_up': -0.2, 'lid_r_up': -0.2,
      'nostril_l': 0.5, 'nostril_r': 0.5,
      'cheek_l': 0.3, 'cheek_r': 0.3,
      'mouth_l': -0.3, 'mouth_r': -0.3,
      'mouth_stretch': 0.2,
      'head_pitch': -0.15,
      'head_yaw': 0.1,
    },
    transitionSpeed: 0.9,
  );

  static const all = [
    neutral, happy, excited, suspicious, angry, sad,
    curious, laughing, smirk, shocked, sleepy, flirty, disgusted,
  ];

  static ExpressionPreset? byName(String name) {
    return all.cast<ExpressionPreset?>().firstWhere(
      (p) => p?.name == name,
      orElse: () => null,
    );
  }
}

/// Micro-expression generator for organic feel
class MicroExpressionEngine {
  final math.Random _rng = math.Random();
  double _time = 0;

  // Procedural noise seeds
  double _seed1 = 0;
  double _seed2 = 0;
  double _seed3 = 0;

  MicroExpressionEngine() {
    _seed1 = _rng.nextDouble() * 1000;
    _seed2 = _rng.nextDouble() * 1000;
    _seed3 = _rng.nextDouble() * 1000;
  }

  /// Generate micro-movements for organic feel
  Map<String, double> generate(double dt, {double intensity = 0.3}) {
    _time += dt;

    // Multi-frequency noise for natural motion
    double noise(double seed, double freq) {
      return math.sin(_time * freq + seed) *
             math.cos(_time * freq * 0.7 + seed * 1.3) *
             math.sin(_time * freq * 0.3 + seed * 0.7);
    }

    return {
      // Subtle eyebrow micro-movements
      'brow_l_mid': noise(_seed1, 0.5) * 0.05 * intensity,
      'brow_r_mid': noise(_seed1 + 10, 0.5) * 0.05 * intensity,

      // Eye micro-saccades
      'pupil_l_x': noise(_seed2, 2.0) * 0.08 * intensity,
      'pupil_l_y': noise(_seed2 + 5, 1.8) * 0.05 * intensity,
      'pupil_r_x': noise(_seed2 + 2, 2.0) * 0.08 * intensity,
      'pupil_r_y': noise(_seed2 + 7, 1.8) * 0.05 * intensity,

      // Breathing through nose
      'nostril_l': (math.sin(_time * 0.8) * 0.5 + 0.5) * 0.1 * intensity,
      'nostril_r': (math.sin(_time * 0.8) * 0.5 + 0.5) * 0.1 * intensity,

      // Subtle head drift
      'head_yaw': noise(_seed3, 0.2) * 0.03 * intensity,
      'head_pitch': noise(_seed3 + 3, 0.15) * 0.02 * intensity,
      'head_roll': noise(_seed3 + 6, 0.1) * 0.015 * intensity,
    };
  }
}

/// Blink controller with natural timing
class BlinkController {
  final math.Random _rng = math.Random();
  double _timeSinceLastBlink = 0;
  double _nextBlinkTime = 2.0;
  double _blinkPhase = 0;  // 0 = open, 1 = closed
  bool _isBlinking = false;

  // Blink curve parameters
  static const double _blinkDownDuration = 0.06;  // 60ms close
  static const double _blinkHoldDuration = 0.04;  // 40ms hold
  static const double _blinkUpDuration = 0.10;    // 100ms open
  static const double _totalBlinkDuration = 0.20;

  double _blinkProgress = 0;

  /// Update and return lid closure amount (0 = open, 1 = closed)
  double update(double dt, {double blinkRate = 1.0}) {
    _timeSinceLastBlink += dt;

    if (_isBlinking) {
      _blinkProgress += dt;

      if (_blinkProgress < _blinkDownDuration) {
        // Closing
        _blinkPhase = _blinkProgress / _blinkDownDuration;
      } else if (_blinkProgress < _blinkDownDuration + _blinkHoldDuration) {
        // Holding closed
        _blinkPhase = 1.0;
      } else if (_blinkProgress < _totalBlinkDuration) {
        // Opening
        final openProgress = (_blinkProgress - _blinkDownDuration - _blinkHoldDuration) / _blinkUpDuration;
        _blinkPhase = 1.0 - openProgress;
      } else {
        // Done
        _isBlinking = false;
        _blinkPhase = 0;
        _blinkProgress = 0;
        _scheduleNextBlink(blinkRate);
      }
    } else if (_timeSinceLastBlink >= _nextBlinkTime) {
      // Start blink
      _isBlinking = true;
      _blinkProgress = 0;
      _timeSinceLastBlink = 0;
    }

    return _blinkPhase;
  }

  void _scheduleNextBlink(double rate) {
    // Average human blink rate: 15-20 per minute
    // Base interval: 3-4 seconds, with variance
    final baseInterval = 3.5 / rate;
    final variance = _rng.nextDouble() * 2.0 - 1.0;  // -1 to 1
    _nextBlinkTime = baseInterval + variance * 1.5;
    _nextBlinkTime = _nextBlinkTime.clamp(1.0, 8.0);
  }

  /// Force a blink now
  void triggerBlink() {
    if (!_isBlinking) {
      _isBlinking = true;
      _blinkProgress = 0;
    }
  }

  /// Double-blink for emphasis
  void triggerDoubleBlink() {
    triggerBlink();
    // Schedule second blink very soon
    _nextBlinkTime = 0.25;
  }
}

/// Gaze controller - where are they looking?
class GazeController {
  double targetX = 0;  // -1 to 1
  double targetY = 0;  // -1 to 1
  double currentX = 0;
  double currentY = 0;

  double _gazeHoldTime = 0;
  double _nextGazeShift = 2.0;
  final math.Random _rng = math.Random();

  /// Update gaze with smooth pursuit
  void update(double dt, {bool autoShift = true}) {
    // Smooth pursuit toward target
    const speed = 8.0;
    currentX += (targetX - currentX) * speed * dt;
    currentY += (targetY - currentY) * speed * dt;

    if (autoShift) {
      _gazeHoldTime += dt;
      if (_gazeHoldTime >= _nextGazeShift) {
        // Random gaze shift
        targetX = (_rng.nextDouble() * 2 - 1) * 0.3;
        targetY = (_rng.nextDouble() * 2 - 1) * 0.2;
        _gazeHoldTime = 0;
        _nextGazeShift = 1.5 + _rng.nextDouble() * 3.0;
      }
    }
  }

  /// Look at specific point
  void lookAt(double x, double y) {
    targetX = x.clamp(-1.0, 1.0);
    targetY = y.clamp(-1.0, 1.0);
    _gazeHoldTime = 0;
    _nextGazeShift = 3.0;  // Hold longer when directed
  }

  /// Look at camera/viewer
  void lookAtCamera() => lookAt(0, 0);

  /// Glance to the side
  void glanceSide(bool left) => lookAt(left ? -0.6 : 0.6, 0);

  /// Look up thinking
  void lookUpThinking() => lookAt(0.2, -0.4);
}

/// Main expression controller - combines everything
class ExpressionController {
  final ExpressionRig rig = ExpressionRig();
  final MicroExpressionEngine microEngine = MicroExpressionEngine();
  final BlinkController blinkController = BlinkController();
  final GazeController gazeController = GazeController();

  ExpressionPreset? _currentPreset;
  ExpressionPreset? _targetPreset;
  double _transitionProgress = 1.0;

  double _microIntensity = 0.3;
  bool _enableMicro = true;
  bool _enableBlink = true;
  bool _enableGaze = true;

  /// Set expression by name
  void setExpression(String name, {bool instant = false}) {
    final preset = ExpressionLibrary.byName(name);
    if (preset != null) {
      if (instant) {
        _applyPresetInstant(preset);
      } else {
        _targetPreset = preset;
        _transitionProgress = 0;
      }
    }
  }

  void _applyPresetInstant(ExpressionPreset preset) {
    rig.reset();
    for (final entry in preset.targets.entries) {
      final point = rig.allPoints.cast<ExpressionPoint?>().firstWhere(
        (p) => p?.id == entry.key,
        orElse: () => null,
      );
      point?.set(entry.value);
    }
    _currentPreset = preset;
    _targetPreset = null;
    _transitionProgress = 1.0;
  }

  /// Main update - call every frame
  void update(double dt) {
    // Expression transition
    if (_targetPreset != null && _transitionProgress < 1.0) {
      _transitionProgress += dt * _targetPreset!.transitionSpeed;
      _transitionProgress = _transitionProgress.clamp(0.0, 1.0);

      // Blend toward target
      for (final entry in _targetPreset!.targets.entries) {
        final point = rig.allPoints.cast<ExpressionPoint?>().firstWhere(
          (p) => p?.id == entry.key,
          orElse: () => null,
        );
        if (point != null) {
          point.springTo(entry.value, dt * _targetPreset!.transitionSpeed * 2);
        }
      }

      if (_transitionProgress >= 1.0) {
        _currentPreset = _targetPreset;
        _targetPreset = null;
      }
    }

    // Micro-expressions
    if (_enableMicro) {
      final micro = microEngine.generate(dt, intensity: _microIntensity);
      for (final entry in micro.entries) {
        final point = rig.allPoints.cast<ExpressionPoint?>().firstWhere(
          (p) => p?.id == entry.key,
          orElse: () => null,
        );
        if (point != null) {
          point.value = (point.value + entry.value).clamp(-1.0, 1.0);
        }
      }
    }

    // Blinking
    if (_enableBlink) {
      final blinkAmount = blinkController.update(dt);
      rig.lidLeftUpper.value = (rig.lidLeftUpper.value - blinkAmount * 0.8).clamp(-1.0, 1.0);
      rig.lidRightUpper.value = (rig.lidRightUpper.value - blinkAmount * 0.8).clamp(-1.0, 1.0);
      rig.lidLeftLower.value = (rig.lidLeftLower.value + blinkAmount * 0.3).clamp(-1.0, 1.0);
      rig.lidRightLower.value = (rig.lidRightLower.value + blinkAmount * 0.3).clamp(-1.0, 1.0);
    }

    // Gaze
    if (_enableGaze) {
      gazeController.update(dt);
      rig.pupilLeftX.value = gazeController.currentX;
      rig.pupilLeftY.value = gazeController.currentY;
      rig.pupilRightX.value = gazeController.currentX;
      rig.pupilRightY.value = gazeController.currentY;
    }

    // Update rig springs
    rig.tick(dt);
  }

  /// Export full state for rendering
  ExpressionState exportState() {
    return ExpressionState(
      rig: rig.export(),
      blinkPhase: blinkController._blinkPhase,
      gazeX: gazeController.currentX,
      gazeY: gazeController.currentY,
      currentEmotion: _currentPreset?.name ?? 'neutral',
    );
  }

  /// Trigger blink
  void blink() => blinkController.triggerBlink();
  void doubleBlink() => blinkController.triggerDoubleBlink();

  /// Gaze controls
  void lookAt(double x, double y) => gazeController.lookAt(x, y);
  void lookAtCamera() => gazeController.lookAtCamera();

  /// Settings
  void setMicroIntensity(double v) => _microIntensity = v.clamp(0.0, 1.0);
  void enableMicro(bool v) => _enableMicro = v;
  void enableBlink(bool v) => _enableBlink = v;
  void enableGaze(bool v) => _enableGaze = v;
}

/// Immutable state snapshot for rendering
class ExpressionState {
  final Map<String, double> rig;
  final double blinkPhase;
  final double gazeX;
  final double gazeY;
  final String currentEmotion;

  const ExpressionState({
    required this.rig,
    required this.blinkPhase,
    required this.gazeX,
    required this.gazeY,
    required this.currentEmotion,
  });

  // Convenience getters
  double get browLeftY => (rig['brow_l_mid'] ?? 0) * 15;  // pixels
  double get browRightY => (rig['brow_r_mid'] ?? 0) * 15;
  double get browLeftRotation => (rig['brow_l_in'] ?? 0) - (rig['brow_l_out'] ?? 0);
  double get browRightRotation => (rig['brow_r_out'] ?? 0) - (rig['brow_r_in'] ?? 0);

  double get lidLeftClosure => 1.0 - ((rig['lid_l_up'] ?? 0) + 1) / 2;
  double get lidRightClosure => 1.0 - ((rig['lid_r_up'] ?? 0) + 1) / 2;

  double get mouthSmileLeft => rig['mouth_l'] ?? 0;
  double get mouthSmileRight => rig['mouth_r'] ?? 0;

  double get headYawDegrees => (rig['head_yaw'] ?? 0) * 30;
  double get headPitchDegrees => (rig['head_pitch'] ?? 0) * 20;
  double get headRollDegrees => (rig['head_roll'] ?? 0) * 15;

  double get pupilDilation => 1.0 + (rig['pupil_dil'] ?? 0) * 0.3;
}
