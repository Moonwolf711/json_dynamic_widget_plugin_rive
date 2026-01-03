import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Enum for resize edge detection
enum ResizeEdge {
  topLeft,
  top,
  topRight,
  left,
  right,
  bottomLeft,
  bottom,
  bottomRight,
  none,
}

/// Professional resizable component using Rect-based approach
/// Compatible with existing WFL callback API while providing Figma-like UX
class WFLResizableComponent extends StatelessWidget {
  final String label;
  final Color color;
  final double scale;
  final void Function(double) onScaleUpdate;
  final void Function(Offset) onDragUpdate;
  final VoidCallback onReset;
  final Widget child;

  // New Rect-based properties (optional, for advanced use)
  final Rect? rect;
  final void Function(Rect)? onRectUpdate;

  const WFLResizableComponent({
    super.key,
    required this.label,
    required this.color,
    required this.scale,
    required this.onScaleUpdate,
    required this.onDragUpdate,
    required this.onReset,
    required this.child,
    this.rect,
    this.onRectUpdate,
  });

  @override
  Widget build(BuildContext context) {
    const handleSize = 14.0;
    const edgeHandleThickness = 8.0;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
          onScaleUpdate(scale + delta);
        }
      },
      // APPLY SCALE via Transform.scale - this is what makes resize actually work!
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main content with border - DRAGGABLE
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) => onDragUpdate(details.delta),
                onDoubleTap: onReset,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withAlpha(179), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: child,
                ),
              ),
            ),

            // Label tag showing scale percentage
            Positioned(
              top: -18,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  '$label ${(scale * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ==================== CORNER RESIZE HANDLES ====================
            // Top-left
            Positioned(
              top: -handleSize / 2,
              left: -handleSize / 2,
              child: _buildCornerHandle(
                cursor: SystemMouseCursors.resizeUpLeft,
                color: color,
                size: handleSize,
                onDrag: (delta) =>
                    onScaleUpdate(scale + (-delta.dx + -delta.dy) * 0.005),
              ),
            ),
            // Top-right
            Positioned(
              top: -handleSize / 2,
              right: -handleSize / 2,
              child: _buildCornerHandle(
                cursor: SystemMouseCursors.resizeUpRight,
                color: color,
                size: handleSize,
                onDrag: (delta) =>
                    onScaleUpdate(scale + (delta.dx + -delta.dy) * 0.005),
              ),
            ),
            // Bottom-left
            Positioned(
              bottom: -handleSize / 2,
              left: -handleSize / 2,
              child: _buildCornerHandle(
                cursor: SystemMouseCursors.resizeDownLeft,
                color: color,
                size: handleSize,
                onDrag: (delta) =>
                    onScaleUpdate(scale + (-delta.dx + delta.dy) * 0.005),
              ),
            ),
            // Bottom-right
            Positioned(
              bottom: -handleSize / 2,
              right: -handleSize / 2,
              child: _buildCornerHandle(
                cursor: SystemMouseCursors.resizeDownRight,
                color: color,
                size: handleSize,
                onDrag: (delta) =>
                    onScaleUpdate(scale + (delta.dx + delta.dy) * 0.005),
              ),
            ),

            // ==================== EDGE RESIZE HANDLES ====================
            // Top edge
            Positioned(
              top: -edgeHandleThickness / 2,
              left: handleSize,
              right: handleSize,
              child: _buildEdgeHandle(
                cursor: SystemMouseCursors.resizeUp,
                height: edgeHandleThickness,
                onDrag: (delta) => onScaleUpdate(scale + (-delta.dy) * 0.005),
              ),
            ),
            // Bottom edge
            Positioned(
              bottom: -edgeHandleThickness / 2,
              left: handleSize,
              right: handleSize,
              child: _buildEdgeHandle(
                cursor: SystemMouseCursors.resizeDown,
                height: edgeHandleThickness,
                onDrag: (delta) => onScaleUpdate(scale + (delta.dy) * 0.005),
              ),
            ),
            // Left edge
            Positioned(
              top: handleSize,
              bottom: handleSize,
              left: -edgeHandleThickness / 2,
              child: _buildEdgeHandle(
                cursor: SystemMouseCursors.resizeLeft,
                width: edgeHandleThickness,
                onDrag: (delta) => onScaleUpdate(scale + (-delta.dx) * 0.005),
              ),
            ),
            // Right edge
            Positioned(
              top: handleSize,
              bottom: handleSize,
              right: -edgeHandleThickness / 2,
              child: _buildEdgeHandle(
                cursor: SystemMouseCursors.resizeRight,
                width: edgeHandleThickness,
                onDrag: (delta) => onScaleUpdate(scale + (delta.dx) * 0.005),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerHandle({
    required MouseCursor cursor,
    required Color color,
    required double size,
    required void Function(Offset) onDrag,
  }) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.4),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle({
    required MouseCursor cursor,
    required void Function(Offset) onDrag,
    double? width,
    double? height,
  }) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: width,
          height: height,
          color: Colors.transparent, // Invisible but interactive
        ),
      ),
    );
  }
}
