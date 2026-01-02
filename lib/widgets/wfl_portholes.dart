import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WFLPortholes extends StatelessWidget {
  final bool flythroughMode;
  final VideoPlayerController? flythroughVideo;
  final VideoPlayerController? porthole1;
  final VideoPlayerController? porthole2;
  final VideoPlayerController? porthole3;
  final Function(int) onPortholeDropped;

  const WFLPortholes({
    super.key,
    required this.flythroughMode,
    this.flythroughVideo,
    this.porthole1,
    this.porthole2,
    this.porthole3,
    required this.onPortholeDropped,
  });

  @override
  Widget build(BuildContext context) {
    // In flythrough mode, show clipped regions of single background video
    if (flythroughMode &&
        flythroughVideo != null &&
        flythroughVideo!.value.isInitialized) {
      return Stack(
        children: [
          // Porthole 1 - Left (shows left portion of video)
          Positioned(
            left: 100,
            top: 80,
            child: _buildFlythroughPorthole(1, const Alignment(-0.7, 0)),
          ),
          // Porthole 2 - Center (shows center portion of video)
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            child: Center(child: _buildFlythroughPorthole(2, Alignment.center)),
          ),
          // Porthole 3 - Right (shows right portion of video)
          Positioned(
            right: 100,
            top: 80,
            child: _buildFlythroughPorthole(3, const Alignment(0.7, 0)),
          ),
        ],
      );
    }

    // Normal mode - 3 independent videos
    return Stack(
      children: [
        // Porthole 1 - Left
        Positioned(
          left: 100,
          top: 80,
          child: _buildPorthole(1, porthole1),
        ),
        // Porthole 2 - Center
        Positioned(
          left: 0,
          right: 0,
          top: 60,
          child: Center(child: _buildPorthole(2, porthole2)),
        ),
        // Porthole 3 - Right
        Positioned(
          right: 100,
          top: 80,
          child: _buildPorthole(3, porthole3),
        ),
      ],
    );
  }

  Widget _buildFlythroughPorthole(int index, Alignment alignment) {
    const size = 150.0;
    final videoWidth = flythroughVideo!.value.size.width;
    final videoHeight = flythroughVideo!.value.size.height;
    final aspectRatio = videoWidth / videoHeight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyan.shade700, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipOval(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            // Make video large enough to clip different regions
            width: size * 3,
            height: size * 3 / aspectRatio,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: alignment,
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(flythroughVideo!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPorthole(int index, VideoPlayerController? controller) {
    const size = 150.0;

    return GestureDetector(
      onTap: () => onPortholeDropped(index),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade700, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          // ClipOval for circular porthole
          child: controller != null && controller.value.isInitialized
              ? VideoPlayer(controller)
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.grey.shade600,
                      size: 40,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
