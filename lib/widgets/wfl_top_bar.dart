import 'package:flutter/material.dart';

import '../wfl_uploader.dart';

class WFLTopBar extends StatelessWidget {
  final bool reactMode;
  final bool flythroughMode;
  final bool showMode;
  final bool isGeneratingCommentary;
  final bool isRecordingMic;
  final bool isLiveMicOn;
  final bool isRecording;
  final int recordingSeconds;

  final Function(bool) onToggleReactMode;
  final VoidCallback onToggleFlythroughMode;
  final VoidCallback onToggleShowMode;
  final VoidCallback onToggleLiveMic;
  final Function(LongPressStartDetails) onStartLiveMicRecording;
  final Function(LongPressEndDetails) onStopLiveMicRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onShowSavePresetDialog;
  final VoidCallback onShowLoadPresetDialog;
  final VoidCallback onToggleYouTube;
  final VoidCallback onShowAIChat;
  final VoidCallback onShowLayerManager;

  const WFLTopBar({
    super.key,
    required this.reactMode,
    required this.flythroughMode,
    required this.showMode,
    required this.isGeneratingCommentary,
    required this.isRecordingMic,
    required this.isLiveMicOn,
    required this.isRecording,
    required this.recordingSeconds,
    required this.onToggleReactMode,
    required this.onToggleFlythroughMode,
    required this.onToggleShowMode,
    required this.onToggleLiveMic,
    required this.onStartLiveMicRecording,
    required this.onStopLiveMicRecording,
    required this.onToggleRecording,
    required this.onShowSavePresetDialog,
    required this.onShowLoadPresetDialog,
    required this.onToggleYouTube,
    required this.onShowAIChat,
    required this.onShowLayerManager,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: const Color(0xFF2a2a3e),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // React Mode toggle
          const Text('React Mode', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          Switch(
            value: reactMode,
            onChanged: onToggleReactMode,
            activeThumbColor: Colors.greenAccent,
          ),
          Text(
            reactMode ? 'ON - Roast + Lip-sync' : 'OFF - Clean playback',
            style: TextStyle(
              color: reactMode ? Colors.greenAccent : Colors.grey,
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 16),

          // Flythrough Mode toggle
          GestureDetector(
            onTap: onToggleFlythroughMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: flythroughMode ? Colors.cyan : const Color(0xFF3a3a4e),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: flythroughMode
                      ? Colors.cyan.shade300
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flight,
                    color: flythroughMode ? Colors.white : Colors.cyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    flythroughMode ? 'FLYTHROUGH' : 'FLY',
                    style: TextStyle(
                      color: flythroughMode ? Colors.white : Colors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SHOW MODE toggle - AI auto-commentary
          GestureDetector(
            onTap: onToggleShowMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: showMode ? Colors.purple : const Color(0xFF3a3a4e),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: showMode ? Colors.purple.shade300 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showMode ? Icons.auto_awesome : Icons.movie_creation,
                    color: showMode ? Colors.white : Colors.purple,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    showMode
                        ? (isGeneratingCommentary ? 'THINKING...' : 'SHOW ON')
                        : 'SHOW',
                    style: TextStyle(
                      color: showMode ? Colors.white : Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // LIVE MIC button - hold to talk, release to roast
          GestureDetector(
            onTap: onToggleLiveMic,
            onLongPressStart: onStartLiveMicRecording,
            onLongPressEnd: onStopLiveMicRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isRecordingMic
                    ? Colors.orange
                    : (isLiveMicOn
                        ? Colors.orange.shade800
                        : const Color(0xFF3a3a4e)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isRecordingMic
                      ? Colors.orange.shade300
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRecordingMic ? Icons.mic : Icons.mic_none,
                    color: isLiveMicOn ? Colors.white : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRecordingMic
                        ? 'LISTENING...'
                        : (isLiveMicOn ? 'MIC ON' : 'LIVE'),
                    style: TextStyle(
                      color: isLiveMicOn ? Colors.white : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // REC button - 30fps capture
          GestureDetector(
            onTap: onToggleRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isRecording ? Colors.red : const Color(0xFF3a3a4e),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isRecording ? Colors.red.shade300 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isRecording ? Colors.white : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? 'REC ${recordingSeconds}s' : 'REC',
                    style: TextStyle(
                      color: isRecording ? Colors.white : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Save Preset button
          TextButton.icon(
            onPressed: onShowSavePresetDialog,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Preset'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),

          // Load Preset button
          TextButton.icon(
            onPressed: onShowLoadPresetDialog,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Load'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),

          const SizedBox(width: 16),

          // YouTube connect/disconnect
          TextButton.icon(
            onPressed: onToggleYouTube,
            icon: Icon(
              WFLUploader.isYouTubeConnected ? Icons.link : Icons.link_off,
              size: 18,
              color:
                  WFLUploader.isYouTubeConnected ? Colors.green : Colors.grey,
            ),
            label: Text(
              WFLUploader.isYouTubeConnected ? 'YouTube ✓' : 'Connect YouTube',
              style: TextStyle(
                color: WFLUploader.isYouTubeConnected
                    ? Colors.green
                    : Colors.white70,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // AI Chat button - Multi-model comedy writer + dev console
          TextButton.icon(
            onPressed: onShowAIChat,
            icon: const Icon(Icons.auto_awesome,
                size: 18, color: Colors.deepPurple),
            label: const Text('AI Writer + Dev',
                style: TextStyle(color: Colors.deepPurple)),
          ),

          const SizedBox(width: 8),

          // Layer Manager button
          TextButton.icon(
            onPressed: onShowLayerManager,
            icon: const Icon(Icons.layers, size: 18, color: Colors.teal),
            label: const Text('Layers', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}
