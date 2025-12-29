// Minimal Terry Rive Widget - just drop in your build()
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'rive_controller.dart';

class TerryWidget extends StatefulWidget {
  const TerryWidget({super.key});

  @override
  State<TerryWidget> createState() => TerryWidgetState();
}

class TerryWidgetState extends State<TerryWidget> {
  final TerryRiveController terry = TerryRiveController();

  @override
  void initState() {
    super.initState();
    terry.load().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    if (!terry.isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Rive(artboard: terry.artboard!);
  }

  // Expose controls for parent widgets
  void setLip(int shape) => terry.setLip(shape);
  void turnHead(double deg) => terry.turnHead(deg);
  void talking(bool on) => terry.talking(on);
  Future<void> lipsync(String phonemes) => terry.lipsync(phonemes);
}

// Usage example:
//
// final GlobalKey<TerryWidgetState> _terryKey = GlobalKey();
//
// TerryWidget(key: _terryKey)
//
// // Then anywhere:
// _terryKey.currentState?.setLip(4);
// _terryKey.currentState?.turnHead(-10);
// _terryKey.currentState?.talking(true);
// await _terryKey.currentState?.lipsync('hello world');
