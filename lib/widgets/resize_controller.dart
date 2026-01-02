/// Professional Rect-based resize controller for Figma-like UIs
/// Separates resize logic from widget for clean architecture
library;

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

/// Controller for managing resizable box state
/// Uses Rect for precise position and size tracking
class ResizeController extends ChangeNotifier {
  Rect _rect;
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final double maxHeight;
  final double? gridSnap; // Optional grid snapping

  ResizeController({
    Rect? initialRect,
    this.minWidth = 50,
    this.minHeight = 50,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    this.gridSnap,
  }) : _rect = initialRect ?? const Rect.fromLTWH(0, 0, 200, 200);

  Rect get rect => _rect;
  double get width => _rect.width;
  double get height => _rect.height;
  double get left => _rect.left;
  double get top => _rect.top;
  Offset get position => Offset(_rect.left, _rect.top);
  Size get size => Size(_rect.width, _rect.height);

  /// Set the rect directly
  void setRect(Rect newRect) {
    _rect = _clampRect(newRect);
    if (gridSnap != null) {
      _rect = _snapToGrid(_rect);
    }
    notifyListeners();
  }

  /// Move the box by delta
  void move(Offset delta) {
    _rect = Rect.fromLTWH(
      _rect.left + delta.dx,
      _rect.top + delta.dy,
      _rect.width,
      _rect.height,
    );
    if (gridSnap != null) {
      _rect = _snapToGrid(_rect);
    }
    notifyListeners();
  }

  /// Resize from a specific edge
  void resize(ResizeEdge edge, Offset delta) {
    double newLeft = _rect.left;
    double newTop = _rect.top;
    double newWidth = _rect.width;
    double newHeight = _rect.height;

    switch (edge) {
      case ResizeEdge.topLeft:
        newLeft += delta.dx;
        newTop += delta.dy;
        newWidth -= delta.dx;
        newHeight -= delta.dy;
        break;
      case ResizeEdge.top:
        newTop += delta.dy;
        newHeight -= delta.dy;
        break;
      case ResizeEdge.topRight:
        newTop += delta.dy;
        newWidth += delta.dx;
        newHeight -= delta.dy;
        break;
      case ResizeEdge.left:
        newLeft += delta.dx;
        newWidth -= delta.dx;
        break;
      case ResizeEdge.right:
        newWidth += delta.dx;
        break;
      case ResizeEdge.bottomLeft:
        newLeft += delta.dx;
        newWidth -= delta.dx;
        newHeight += delta.dy;
        break;
      case ResizeEdge.bottom:
        newHeight += delta.dy;
        break;
      case ResizeEdge.bottomRight:
        newWidth += delta.dx;
        newHeight += delta.dy;
        break;
      case ResizeEdge.none:
        return;
    }

    _rect = _clampRect(Rect.fromLTWH(newLeft, newTop, newWidth, newHeight));
    if (gridSnap != null) {
      _rect = _snapToGrid(_rect);
    }
    notifyListeners();
  }

  /// Scale uniformly from center
  void scale(double factor) {
    final center = _rect.center;
    final newWidth = (_rect.width * factor).clamp(minWidth, maxWidth);
    final newHeight = (_rect.height * factor).clamp(minHeight, maxHeight);
    _rect = Rect.fromCenter(
      center: center,
      width: newWidth,
      height: newHeight,
    );
    notifyListeners();
  }

  /// Reset to initial size at current position
  void resetSize(double defaultWidth, double defaultHeight) {
    _rect = Rect.fromLTWH(
      _rect.left,
      _rect.top,
      defaultWidth,
      defaultHeight,
    );
    notifyListeners();
  }

  /// Reset to origin
  void resetPosition() {
    _rect = Rect.fromLTWH(0, 0, _rect.width, _rect.height);
    notifyListeners();
  }

  /// Full reset
  void reset(Rect defaultRect) {
    _rect = defaultRect;
    notifyListeners();
  }

  Rect _clampRect(Rect r) {
    return Rect.fromLTWH(
      r.left,
      r.top,
      r.width.clamp(minWidth, maxWidth),
      r.height.clamp(minHeight, maxHeight),
    );
  }

  Rect _snapToGrid(Rect r) {
    if (gridSnap == null) return r;
    final snap = gridSnap!;
    return Rect.fromLTWH(
      (r.left / snap).round() * snap,
      (r.top / snap).round() * snap,
      (r.width / snap).round() * snap,
      (r.height / snap).round() * snap,
    );
  }
}

/// Widget that provides a resizable box with edge handles
/// Uses MouseRegion for desktop/web cursor support
class ResizableBox extends StatelessWidget {
  final ResizeController controller;
  final Widget child;
  final Color borderColor;
  final Color handleColor;
  final double handleSize;
  final String? label;
  final bool showLabel;
  final bool showHandles;
  final VoidCallback? onDoubleTap;

  const ResizableBox({
    super.key,
    required this.controller,
    required this.child,
    this.borderColor = Colors.cyan,
    this.handleColor = Colors.cyan,
    this.handleSize = 12.0,
    this.label,
    this.showLabel = true,
    this.showHandles = true,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SizedBox(
          width: controller.width,
          height: controller.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main content with drag to move
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) => controller.move(details.delta),
                    onDoubleTap: onDoubleTap,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor.withAlpha(180),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),

              // Label tag
              if (showLabel && label != null)
                Positioned(
                  top: -18,
                  left: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      '$label ${controller.width.toInt()}x${controller.height.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Resize handles
              if (showHandles) ...[
                // Top-left
                _buildHandle(ResizeEdge.topLeft, -handleSize / 2, null, null,
                    -handleSize / 2),
                // Top-right
                _buildHandle(ResizeEdge.topRight, -handleSize / 2,
                    -handleSize / 2, null, null),
                // Bottom-left
                _buildHandle(ResizeEdge.bottomLeft, null, null, -handleSize / 2,
                    -handleSize / 2),
                // Bottom-right
                _buildHandle(ResizeEdge.bottomRight, null, -handleSize / 2,
                    -handleSize / 2, null),
                // Top edge
                _buildEdgeHandle(ResizeEdge.top, -4, handleSize, null,
                    handleSize, controller.width - handleSize * 2),
                // Bottom edge
                _buildEdgeHandle(ResizeEdge.bottom, null, handleSize, -4,
                    handleSize, controller.width - handleSize * 2),
                // Left edge
                _buildEdgeHandle(ResizeEdge.left, handleSize, -4, handleSize,
                    null, null, controller.height - handleSize * 2),
                // Right edge
                _buildEdgeHandle(ResizeEdge.right, handleSize, null, handleSize,
                    -4, null, controller.height - handleSize * 2),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(ResizeEdge edge, double? top, double? right,
      double? bottom, double? left) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: MouseRegion(
        cursor: _getCursor(edge),
        child: GestureDetector(
          onPanUpdate: (details) => controller.resize(edge, details.delta),
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: handleColor,
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
      ),
    );
  }

  Widget _buildEdgeHandle(
      ResizeEdge edge, double? top, double? left, double? bottom, double? right,
      [double? width, double? height]) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: MouseRegion(
        cursor: _getCursor(edge),
        child: GestureDetector(
          onPanUpdate: (details) => controller.resize(edge, details.delta),
          child: Container(
            width: width ?? 8,
            height: height ?? 8,
            color: Colors.transparent, // Invisible edge handles
          ),
        ),
      ),
    );
  }

  MouseCursor _getCursor(ResizeEdge edge) {
    switch (edge) {
      case ResizeEdge.topLeft:
        return SystemMouseCursors.resizeUpLeft;
      case ResizeEdge.top:
        return SystemMouseCursors.resizeUp;
      case ResizeEdge.topRight:
        return SystemMouseCursors.resizeUpRight;
      case ResizeEdge.left:
        return SystemMouseCursors.resizeLeft;
      case ResizeEdge.right:
        return SystemMouseCursors.resizeRight;
      case ResizeEdge.bottomLeft:
        return SystemMouseCursors.resizeDownLeft;
      case ResizeEdge.bottom:
        return SystemMouseCursors.resizeDown;
      case ResizeEdge.bottomRight:
        return SystemMouseCursors.resizeDownRight;
      case ResizeEdge.none:
        return SystemMouseCursors.basic;
    }
  }
}

/// Convenience widget that auto-creates a controller
/// For simpler use cases where you don't need external controller access
class SimpleResizableBox extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double initialHeight;
  final double initialX;
  final double initialY;
  final Color borderColor;
  final String? label;
  final void Function(Rect)? onChanged;
  final VoidCallback? onReset;

  const SimpleResizableBox({
    super.key,
    required this.child,
    this.initialWidth = 200,
    this.initialHeight = 200,
    this.initialX = 0,
    this.initialY = 0,
    this.borderColor = Colors.cyan,
    this.label,
    this.onChanged,
    this.onReset,
  });

  @override
  State<SimpleResizableBox> createState() => _SimpleResizableBoxState();
}

class _SimpleResizableBoxState extends State<SimpleResizableBox> {
  late ResizeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ResizeController(
      initialRect: Rect.fromLTWH(
        widget.initialX,
        widget.initialY,
        widget.initialWidth,
        widget.initialHeight,
      ),
    );
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    widget.onChanged?.call(_controller.rect);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResizableBox(
      controller: _controller,
      borderColor: widget.borderColor,
      label: widget.label,
      onDoubleTap: () {
        _controller.reset(Rect.fromLTWH(
          widget.initialX,
          widget.initialY,
          widget.initialWidth,
          widget.initialHeight,
        ));
        widget.onReset?.call();
      },
      child: widget.child,
    );
  }
}
