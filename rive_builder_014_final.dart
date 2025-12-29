import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:rive/rive.dart' as rive;

part 'rive_builder.g.dart';

/// Creates a [rive.RiveWidget] widget.
///
/// Updated for Rive 0.14.0 which uses the new C++ runtime.
///
/// **Breaking changes from 0.13.x:**
/// - `fit` now uses `rive.Fit` instead of `BoxFit`
/// - Uses `RiveWidgetBuilder` pattern instead of removed `RiveAnimation` widget
/// - File loading is now async via `FileLoader`
/// - Artboard/StateMachine selection uses selector classes
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
    this.layoutScaleFactor = 1.0,
    this.package,
    this.placeholder,
    this.rive,
    this.stateMachines,
    this.url,
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
  final double layoutScaleFactor;
  final String? package;
  final JsonWidgetData? placeholder;
  final List<String>? stateMachines;
  final String? rive;
  final String? url;

  @override
  State<_Rive> createState() => _RiveState();
}

class _RiveState extends State<_Rive> {
  rive.FileLoader? _fileLoader;

  @override
  void initState() {
    super.initState();
    _initFileLoader();
  }

  @override
  void didUpdateWidget(covariant _Rive oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if source changed
    if (oldWidget.asset != widget.asset ||
        oldWidget.url != widget.url ||
        oldWidget.rive != widget.rive) {
      _fileLoader?.dispose();
      _initFileLoader();
    }
  }

  void _initFileLoader() {
    if (widget.asset != null) {
      final assetPath = widget.package == null
          ? widget.asset!
          : 'packages/${widget.package}/${widget.asset}';
      _fileLoader = rive.FileLoader.fromAsset(
        assetPath,
        riveFactory: rive.Factory.rive,
      );
    } else if (widget.url != null) {
      _fileLoader = rive.FileLoader.fromUrl(
        widget.url!,
        riveFactory: rive.Factory.rive,
      );
    } else if (widget.rive != null) {
      // For base64-encoded rive data, we need to load it differently
      // Using a custom approach since FileLoader doesn't support bytes directly
      _fileLoader = _Base64FileLoader(
        widget.rive!,
        riveFactory: rive.Factory.rive,
      );
    }
    setState(() {});
  }

  /// Get the artboard selector based on widget config
  rive.ArtboardSelector get _artboardSelector {
    if (widget.artboard != null) {
      return rive.ArtboardSelector.byName(widget.artboard!);
    }
    return const rive.ArtboardSelector.byDefault();
  }

  /// Get the state machine selector based on widget config
  rive.StateMachineSelector get _stateMachineSelector {
    if (widget.stateMachines != null && widget.stateMachines!.isNotEmpty) {
      return rive.StateMachineSelector.byName(widget.stateMachines!.first);
    }
    // If animations specified, don't use state machine
    if (widget.animations != null && widget.animations!.isNotEmpty) {
      return const rive.StateMachineSelector.none();
    }
    return const rive.StateMachineSelector.byDefault();
  }

  @override
  void dispose() {
    _fileLoader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fileLoader == null) {
      return _buildPlaceholder(context);
    }

    return rive.RiveWidgetBuilder(
      fileLoader: _fileLoader!,
      artboardSelector: _artboardSelector,
      stateMachineSelector: _stateMachineSelector,
      builder: (context, state) {
        return switch (state) {
          rive.RiveLoading() => _buildPlaceholder(context),
          rive.RiveLoaded(:final controller) => rive.RiveWidget(
              controller: controller,
              fit: widget.fit,
              alignment: widget.alignment,
              layoutScaleFactor: widget.layoutScaleFactor,
            ),
          rive.RiveFailed(:final error) => _buildError(error.toString()),
        };
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return widget.placeholder?.build(
          childBuilder: widget.childBuilder,
          context: context,
        ) ??
        const Center(child: CircularProgressIndicator());
  }

  Widget _buildError(String error) {
    return Center(
      child: Text(
        'Rive Error: $error',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

/// Custom FileLoader for base64-encoded Rive data
/// This handles the case where rive data is passed as a base64 string
class _Base64FileLoader extends rive.FileLoader {
  _Base64FileLoader(
    this._base64Data, {
    required rive.Factory Function() riveFactory,
  }) : super.fromFile(
          _createDummyFile(),
          riveFactory: riveFactory,
        );

  final String _base64Data;
  rive.File? _loadedFile;

  static rive.File _createDummyFile() {
    // This is a workaround - we'll override the file() method
    throw UnimplementedError('Use file() method instead');
  }

  @override
  Future<rive.File> file() async {
    if (_loadedFile != null) {
      return _loadedFile!;
    }

    final bytes = base64.decode(_base64Data);
    _loadedFile = await rive.File.bytes(
      Uint8List.fromList(bytes),
    );
    return _loadedFile!;
  }

  @override
  rive.File? get fileSync => _loadedFile;

  @override
  void dispose() {
    _loadedFile?.dispose();
    super.dispose();
  }
}
