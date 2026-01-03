import 'package:flutter/material.dart';

class WFLBottomControls extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onExport;
  final VoidCallback onExportAndPost;
  final int roastNumber;

  const WFLBottomControls({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    required this.onExport,
    required this.onExportAndPost,
    required this.roastNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(
            volume < 0.3
                ? Icons.volume_mute
                : (volume < 0.7 ? Icons.volume_down : Icons.volume_up),
            color: Colors.white54,
            size: 20,
          ),
          Expanded(
            child: Slider(
              value: volume,
              min: 0,
              max: 1,
              onChanged: onVolumeChanged,
              activeColor: Colors.greenAccent,
              inactiveColor: Colors.grey.shade700,
            ),
          ),
          Text(
            volume < 0.3 ? 'Whisper' : (volume < 0.7 ? 'Normal' : 'Loud'),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(width: 12),
          // Export button
          ElevatedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.movie, size: 16),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          // Export & Post - the one-click nuclear option
          ElevatedButton.icon(
            onPressed: onExportAndPost,
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: Text('Post #$roastNumber'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
