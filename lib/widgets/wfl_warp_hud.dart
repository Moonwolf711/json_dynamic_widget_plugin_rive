import 'package:flutter/material.dart';

class WFLWarpHUD extends StatelessWidget {
  final double warpSpeed;

  const WFLWarpHUD({
    super.key,
    required this.warpSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top scanline
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                height: 1,
                color: const Color.fromRGBO(76, 175, 80, 0.3),
              ),
            ),

            // Bottom HUD bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color.fromRGBO(0, 0, 0, 0.7)
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Warp speed
                    Text(
                      'WARP ${warpSpeed.toStringAsFixed(2)}c',
                      style: TextStyle(
                        color: Colors.green.shade400,
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 30),

                    // Destination
                    Text(
                      'DEST: VIRAL CLIP',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),

                    const Spacer(),

                    // Exit hint
                    Text(
                      '[SHIFT+W] EXIT WARP',
                      style: TextStyle(
                        color: Colors.green.shade500,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Corner brackets (HUD frame)
            ..._buildHUDCorners(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHUDCorners() {
    const cornerSize = 30.0;
    const color = Colors.green;
    const thickness = 2.0;

    return [
      // Top-left
      Positioned(
        top: 10,
        left: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 10,
        right: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 40,
        left: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 40,
        right: 10,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
    ];
  }
}
