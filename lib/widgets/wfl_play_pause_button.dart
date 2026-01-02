import 'package:flutter/material.dart';

class WFLPlayPauseButton extends StatelessWidget {
  final bool dialoguePlaying;
  final bool dialoguePaused;
  final VoidCallback onToggle;
  final VoidCallback onStop;

  const WFLPlayPauseButton({
    super.key,
    required this.dialoguePlaying,
    required this.dialoguePaused,
    required this.onToggle,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = dialoguePlaying && !dialoguePaused;
    final isPaused = dialoguePlaying && dialoguePaused;

    return Positioned(
      bottom: 120,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Main Play/Pause button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPlaying
                      ? [Colors.green.shade400, Colors.green.shade700]
                      : isPaused
                          ? [Colors.orange.shade400, Colors.orange.shade700]
                          : [Colors.purple.shade400, Colors.purple.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPlaying
                            ? Colors.green
                            : isPaused
                                ? Colors.orange
                                : Colors.purple)
                        .withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
                border:
                    Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Status label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPlaying
                  ? 'PLAYING'
                  : isPaused
                      ? 'PAUSED'
                      : 'DIALOGUE',
              style: TextStyle(
                color: isPlaying
                    ? Colors.green
                    : isPaused
                        ? Colors.orange
                        : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Stop button (only when playing or paused)
          if (dialoguePlaying)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade700,
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
