/// Rive stub classes for when Rive is disabled
/// This allows the code to compile without the rive package

import 'package:flutter/widgets.dart';

/// Stub RiveFile
class RiveFile {
  static Future<void> initialize() async {}

  static RiveFile import(dynamic data) => RiveFile();

  Artboard? get mainArtboard => null;

  Artboard? artboardByName(String name) => null;
}

/// Stub Artboard
class Artboard {
  String get name => '';

  Artboard instance() => Artboard();

  void addController(dynamic controller) {}
}

/// Stub StateMachineController
class StateMachineController {
  final StateMachine stateMachine = StateMachine();

  static StateMachineController? fromArtboard(Artboard artboard, String name) => null;

  T? findInput<T>(String name) => null;

  void dispose() {}
}

/// Stub StateMachine
class StateMachine {
  String get name => '';
}

/// Stub SMIBool
class SMIBool extends SMIInput<bool> {
  @override
  bool value = false;
}

/// Stub SMINumber
class SMINumber extends SMIInput<double> {
  @override
  double value = 0;
}

/// Stub SMIInput with value setter
class SMIInput<T> {
  T? _value;
  T get value => _value as T;
  set value(T val) => _value = val;
}

/// Stub SMITrigger
class SMITrigger extends SMIInput<bool> {
  void fire() {}
}

/// Stub RiveAnimationController
abstract class RiveAnimationController<T> {
  bool get isActive;
}

/// Stub SimpleAnimation
class SimpleAnimation extends RiveAnimationController<Object> {
  SimpleAnimation(String animationName, {bool autoplay = true});

  @override
  bool get isActive => false;
}

/// Stub Rive widget
class Rive extends StatelessWidget {
  final Artboard? artboard;
  final BoxFit? fit;
  final Alignment? alignment;

  const Rive({
    super.key,
    this.artboard,
    this.fit,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
