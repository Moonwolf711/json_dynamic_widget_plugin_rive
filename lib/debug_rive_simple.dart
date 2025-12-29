// Simple Rive debugger - prints state machines and inputs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugRive();
}

Future<void> debugRive() async {
  try {
    await RiveFile.initialize();
    final bytes = await rootBundle.load('assets/wfl.riv');
    final file = RiveFile.import(bytes);

    print('=== RIVE FILE DEBUG ===');
    print('');
    print('Main artboard: ${file.mainArtboard.name}');

    final artboard = file.mainArtboard.instance();

    // Try known state machine names
    final smNames = [
      'cockpit', 'main', 'Main', 'CockpitSM', 'Cockpit', 'State Machine 1',
    ];

    print('');
    print('=== STATE MACHINES BY NAME ===');
    print('');

    for (final name in smNames) {
      final controller = StateMachineController.fromArtboard(artboard, name);
      if (controller != null) {
        print('FOUND: $name');
        print('  Inputs (${controller.inputs.length}):');
        for (final input in controller.inputs) {
          print('    - ${input.name} (${input.runtimeType})');
        }
        print('');
      }
    }

    print('');
    print('=== ALL ANIMATIONS ===');
    print('');

    // List all animations (not state machines, but useful)
    for (int i = 0; i < 20; i++) {
      try {
        final anim = file.mainArtboard.animationByIndex(i);
        print('Animation[$i]: ${anim.name}');
      } catch (e) {
        break;
      }
    }

    print('');
    print('Done. Exiting.');

  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }

  // Exit the app
  exit(0);
}

void exit(int code) {
  // Can't actually exit in Flutter without platform channel
  // But we'll let it sit
}
