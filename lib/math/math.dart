// math.dart - Math utilities and constants
// 100% original IP for WFL animation system

import 'dart:math' as math;

/// Math constants
class MathConstants {
  MathConstants._();

  static const double pi = math.pi;
  static const double twoPi = 2 * math.pi;
  static const double halfPi = math.pi / 2;
  static const double quarterPi = math.pi / 4;

  static const double e = math.e;
  static const double ln2 = math.ln2;
  static const double ln10 = math.ln10;
  static const double log2e = math.log2e;
  static const double log10e = math.log10e;
  static const double sqrt2 = math.sqrt2;
  static const double sqrt1_2 = math.sqrt1_2;

  /// Golden ratio
  static const double phi = 1.6180339887498948;

  /// Degrees to radians multiplier
  static const double deg2Rad = math.pi / 180;

  /// Radians to degrees multiplier
  static const double rad2Deg = 180 / math.pi;

  /// Very small number for floating point comparisons
  static const double epsilon = 1e-10;
}

/// Math utility functions
class MathUtils {
  MathUtils._();

  /// Convert degrees to radians
  static double toRadians(double degrees) => degrees * MathConstants.deg2Rad;

  /// Convert radians to degrees
  static double toDegrees(double radians) => radians * MathConstants.rad2Deg;

  /// Linear interpolation
  static double lerp(double a, double b, double t) => a + (b - a) * t;

  /// Inverse linear interpolation (find t given value)
  static double inverseLerp(double a, double b, double value) {
    if (a == b) return 0;
    return (value - a) / (b - a);
  }

  /// Remap value from one range to another
  static double remap(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax,
  ) {
    final t = inverseLerp(inMin, inMax, value);
    return lerp(outMin, outMax, t);
  }

  /// Clamp value between min and max
  static double clamp(double value, double min, double max) =>
      value.clamp(min, max);

  /// Clamp to 0-1 range
  static double saturate(double value) => value.clamp(0, 1);

  /// Smooth step interpolation
  static double smoothStep(double t) {
    t = t.clamp(0, 1);
    return t * t * (3 - 2 * t);
  }

  /// Smoother step interpolation (C2 continuous)
  static double smootherStep(double t) {
    t = t.clamp(0, 1);
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  /// Ping-pong value between 0 and length
  static double pingPong(double t, double length) {
    t = t % (length * 2);
    return length - (t - length).abs();
  }

  /// Repeat value between 0 and length
  static double repeat(double t, double length) {
    return t - (t / length).floor() * length;
  }

  /// Delta angle (shortest rotation)
  static double deltaAngle(double current, double target) {
    var delta = repeat(target - current, MathConstants.twoPi);
    if (delta > math.pi) {
      delta -= MathConstants.twoPi;
    }
    return delta;
  }

  /// Move value towards target by max delta
  static double moveTowards(double current, double target, double maxDelta) {
    if ((target - current).abs() <= maxDelta) {
      return target;
    }
    return current + (target - current).sign * maxDelta;
  }

  /// Move angle towards target by max delta (handles wrapping)
  static double moveTowardsAngle(
    double current,
    double target,
    double maxDelta,
  ) {
    final delta = deltaAngle(current, target);
    if (delta.abs() <= maxDelta) {
      return target;
    }
    return current + delta.sign * maxDelta;
  }

  /// Smooth damp (critically damped spring)
  static (double, double) smoothDamp(
    double current,
    double target,
    double currentVelocity,
    double smoothTime,
    double deltaTime, {
    double maxSpeed = double.infinity,
  }) {
    smoothTime = math.max(0.0001, smoothTime);
    final omega = 2 / smoothTime;

    final x = omega * deltaTime;
    final exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
    var change = current - target;
    final originalTo = target;

    // Clamp maximum speed
    final maxChange = maxSpeed * smoothTime;
    change = change.clamp(-maxChange, maxChange);
    final newTarget = current - change;

    final temp = (currentVelocity + omega * change) * deltaTime;
    var newVelocity = (currentVelocity - omega * temp) * exp;
    var output = newTarget + (change + temp) * exp;

    // Prevent overshooting
    if ((originalTo - current > 0) == (output > originalTo)) {
      output = originalTo;
      newVelocity = (output - originalTo) / deltaTime;
    }

    return (output, newVelocity);
  }

  /// Approximately equal (floating point comparison)
  static bool approximately(double a, double b,
      [double epsilon = MathConstants.epsilon]) {
    return (a - b).abs() < epsilon;
  }

  /// Sign of value (-1, 0, or 1)
  static int sign(double value) {
    if (value > 0) return 1;
    if (value < 0) return -1;
    return 0;
  }

  /// Fractional part
  static double fract(double value) => value - value.floor();

  /// Step function (0 if value < edge, 1 otherwise)
  static double step(double edge, double value) => value < edge ? 0 : 1;

  /// Power of 2 check
  static bool isPowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;

  /// Next power of 2
  static int nextPowerOfTwo(int value) {
    if (value <= 0) return 1;
    value--;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    return value + 1;
  }

  /// Wrap value to range [min, max)
  static double wrap(double value, double min, double max) {
    final range = max - min;
    return min + ((value - min) % range + range) % range;
  }

  /// Exponential decay (useful for smooth following)
  static double expDecay(double a, double b, double decay, double dt) {
    return b + (a - b) * math.exp(-decay * dt);
  }

  /// Spring interpolation
  static double spring(
    double current,
    double target,
    double velocity,
    double stiffness,
    double damping,
    double dt,
  ) {
    final force = -stiffness * (current - target) - damping * velocity;
    final newVelocity = velocity + force * dt;
    return current + newVelocity * dt;
  }

  /// Easing functions
  static double easeInQuad(double t) => t * t;
  static double easeOutQuad(double t) => t * (2 - t);
  static double easeInOutQuad(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  static double easeInCubic(double t) => t * t * t;
  static double easeOutCubic(double t) => (--t) * t * t + 1;
  static double easeInOutCubic(double t) =>
      t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;

  static double easeInSine(double t) => 1 - math.cos(t * MathConstants.halfPi);
  static double easeOutSine(double t) => math.sin(t * MathConstants.halfPi);
  static double easeInOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;

  static double easeInExpo(double t) =>
      t == 0 ? 0 : math.pow(2, 10 * t - 10).toDouble();
  static double easeOutExpo(double t) =>
      t == 1 ? 1 : 1 - math.pow(2, -10 * t).toDouble();

  static double easeInElastic(double t) {
    if (t == 0 || t == 1) return t;
    return -math.pow(2, 10 * t - 10).toDouble() *
        math.sin((t * 10 - 10.75) * (2 * math.pi / 3));
  }

  static double easeOutElastic(double t) {
    if (t == 0 || t == 1) return t;
    return math.pow(2, -10 * t).toDouble() *
            math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) +
        1;
  }

  static double easeOutBounce(double t) {
    if (t < 1 / 2.75) {
      return 7.5625 * t * t;
    } else if (t < 2 / 2.75) {
      t -= 1.5 / 2.75;
      return 7.5625 * t * t + 0.75;
    } else if (t < 2.5 / 2.75) {
      t -= 2.25 / 2.75;
      return 7.5625 * t * t + 0.9375;
    } else {
      t -= 2.625 / 2.75;
      return 7.5625 * t * t + 0.984375;
    }
  }

  static double easeInBounce(double t) => 1 - easeOutBounce(1 - t);
}
