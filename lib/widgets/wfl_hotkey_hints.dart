import 'package:flutter/material.dart';

class WFLHotkeyHints extends StatelessWidget {
  final bool hasFocus;
  final bool isWarp;
  final bool flythroughMode;
  final VoidCallback onRequestFocus;

  const WFLHotkeyHints({
    super.key,
    required this.hasFocus,
    required this.isWarp,
    required this.flythroughMode,
    required this.onRequestFocus,
  });

  @override
  Widget build(BuildContext context) {
    // Show focus hint if keyboard lost focus
    if (!hasFocus) {
      return GestureDetector(
        onTap: onRequestFocus,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Click cockpit to control',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('F1 Thrusters',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
          const Text('F2 Warp',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
          const Text('F3 Shields',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
          if (!isWarp)
            const Text('SHIFT+W Warp Mode',
                style: TextStyle(fontSize: 10, color: Colors.green)),
          Text(
            flythroughMode ? 'SHIFT+T Exit Flythrough' : 'SHIFT+T Flythrough',
            style: TextStyle(
                fontSize: 10,
                color: flythroughMode ? Colors.cyan : Colors.cyan.shade300),
          ),
          const Text('SHIFT+F Focus Mode',
              style: TextStyle(fontSize: 10, color: Colors.cyan)),
        ],
      ),
    );
  }
}
