import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:rive/rive.dart' as rive;

part 'rive_builder.g.dart';

/// Creates a [rive.RiveWidget] widget.
///
/// Updated for Rive 0.14.0 which uses the new C++ runtime.
@jsonWidget
abstract class _RiveBuilder extends JsonWidgetBuilder {
  const _RiveBuilder({
    super.args,
  });

  @override
  _Rive buildCustom({
    ChildWidgetBuilder? childBuilder,
    required BuildContext context,
    required JsonWidgetData data,
    Key? key,
  });
}

class _Rive extends StatefulWidget {
  const _Rive({
    this.alignment = Alignment.center,
    this.animations,
    this.antialiasing = true,
    this.artboard,
    this.asset,
    @JsonBuildArg() this.childBuilder,
    this.fit = rive.Fit.contain,
    super.key,
    this.package,
    this.placeholder,
    this.rive,
    this.stateMachines,
    this.url,
    this.useArtboardSize = false,
  })  : assert((asset == null && url == null) ||
            (asset == null && rive == null) ||
            (rive == null && url == null)),
        assert(asset != null || rive != null || url != null);

  final Alignment alignment;
  final List<String>? animations;
  final bool antialiasing;
  final String? artboard;
  final String? asset;
  final ChildWidgetBuilder? childBuilder;
  final rive.Fit fit;
  final String? package;
  final JsonWidgetData? placeholder;
  final List<String>? stateMachines;
  final String? rive;
  final String? url;
  final bool useArtboardSize;

  @override
  State<_Rive> createState() => _RiveState();
}

class _RiveState extends State<_Rive> {
  rive.File? _file;
  rive.RiveController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  @override
  void didUpdateWidget(covariant _Rive oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if source changed
    if (oldWidget.asset != widget.asset ||
        oldWidget.url != widget.url ||
        oldWidget.rive != widget.rive ||
        oldWidget.artboard != widget.artboard) {
      _disposeRive();
      _loadRive();
    }
  }

  Future<void> _loadRive() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load the file based on source type
      if (widget.asset != null) {
        final assetPath = widget.package == null
            ? widget.asset!
            : 'packages/${widget.package}/${widget.asset}';
        _file = await rive.File.asset(assetPath);
      } else if (widget.url != null) {
        _file = await rive.File.network(widget.url!);
      } else if (widget.rive != null) {
        // Base64 encoded rive data
        final bytes = base64.decode(widget.rive!);
        _file = await rive.File.bytes(bytes);
      }

      if (_file == null) {
        throw Exception('Failed to load Rive file');
      }

      // Create controller with artboard and state machine selection
      _controller = await _file!.createController(
        artboardName: widget.artboard,
        stateMachineName: _getStateMachineName(),
        animationName: _getAnimationName(),
        autoplay: true,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  String? _getStateMachineName() {
    if (widget.stateMachines != null && widget.stateMachines!.isNotEmpty) {
      return widget.stateMachines!.first;
    }
    return null;
  }

  String? _getAnimationName() {
    if (widget.animations != null && widget.animations!.isNotEmpty) {
      return widget.animations!.first;
    }
    return null;
  }

  void _disposeRive() {
    _controller?.dispose();
    _controller = null;
    _file?.dispose();
    _file = null;
  }

  @override
  void dispose() {
    _disposeRive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder while loading
    if (_isLoading) {
      return widget.placeholder?.build(
            childBuilder: widget.childBuilder,
            context: context,
          ) ??
          const Center(child: CircularProgressIndicator());
    }

    // Show error if failed
    if (_error != null || _controller == null) {
      return Center(
        child: Text(
          _error ?? 'Failed to load Rive animation',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // Build the RiveWidget
    return rive.RiveWidget(
      controller: _controller!,
      fit: widget.fit,
      alignment: widget.alignment,
      antialiasing: widget.antialiasing,
      useArtboardSize: widget.useArtboardSize,
    );
  }
}
