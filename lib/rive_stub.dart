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
<<<<<<< HEAD

/// Stub FileLoader for Rive 0.14.0 API
class FileLoader {
  FileLoader.fromAsset(String assetPath, {Factory? riveFactory});

  void dispose() {}
}

/// Stub Factory enum
class Factory {
  static const Factory rive = Factory._();
  const Factory._();
}

/// Stub RiveWidgetController
class RiveWidgetController {
  StateMachineController? stateMachine;

  void dispose() {}
}

/// Stub StateMachineSelector
class StateMachineSelector {
  static StateMachineSelector byName(String name) => StateMachineSelector();
}

/// Stub RiveWidgetBuilder
class RiveWidgetBuilder extends StatelessWidget {
  final FileLoader fileLoader;
  final StateMachineSelector? stateMachineSelector;
  final void Function(RiveLoaded)? onLoaded;
  final Widget Function(BuildContext, RiveState) builder;

  const RiveWidgetBuilder({
    super.key,
    required this.fileLoader,
    this.stateMachineSelector,
    this.onLoaded,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // Return loading state by default for stub
    return builder(context, RiveLoading());
  }
}

/// Stub RiveState sealed class hierarchy
sealed class RiveState {}

class RiveLoading extends RiveState {}

class RiveFailed extends RiveState {
  final Object error;
  RiveFailed({required this.error});
}

class RiveLoaded extends RiveState {
  final RiveWidgetController controller;
  RiveLoaded({required this.controller});
}

/// Stub RiveWidget
class RiveWidget extends StatelessWidget {
  final RiveWidgetController controller;
  final Fit? fit;

  const RiveWidget({
    super.key,
    required this.controller,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Stub Fit enum
enum Fit {
  contain,
  cover,
  fill,
  fitWidth,
  fitHeight,
  none,
  scaleDown,
}
=======
>>>>>>> 4bf1e273a0b3d10ab83264b6e20e5449cea26cfc
