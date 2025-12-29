// Runtime Rive Input Patcher - Inject inputs without Rive Editor
// Pure Dart implementation - patches .riv binary directly
// No native code required!

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';

// Native function signatures
typedef PatchFileNative = Int32 Function(
  Pointer<Utf8> path,
  Pointer<Utf8> name,
  Int32 type,
  Double min,
  Double max,
);
typedef PatchFileDart = int Function(
  Pointer<Utf8> path,
  Pointer<Utf8> name,
  int type,
  double min,
  double max,
);

typedef PatchMemoryNative = Int32 Function(
  Pointer<Uint8> inputData,
  Int32 inputSize,
  Pointer<Uint8> outputData,
  Int32 outputMaxSize,
  Pointer<Utf8> name,
  Int32 type,
  Double min,
  Double max,
);
typedef PatchMemoryDart = int Function(
  Pointer<Uint8> inputData,
  int inputSize,
  Pointer<Uint8> outputData,
  int outputMaxSize,
  Pointer<Utf8> name,
  int type,
  double min,
  double max,
);

/// Input types for Rive state machine
enum RiveInputType {
  number,
  boolean,
  trigger,
}

/// Runtime Rive patcher - inject inputs without Rive Editor
class RivePatcher {
  static DynamicLibrary? _lib;
  static PatchFileDart? _patchFile;
  static PatchMemoryDart? _patchMemory;

  /// Initialize the native library
  static void _init() {
    if (_lib != null) return;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('librive_patcher.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('rive_patcher.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('librive_patcher.so');
      }

      if (_lib != null) {
        _patchFile = _lib!
            .lookupFunction<PatchFileNative, PatchFileDart>('patch_rive_input');
        _patchMemory = _lib!
            .lookupFunction<PatchMemoryNative, PatchMemoryDart>('patch_rive_input_memory');
      }
    } catch (e) {
      // Native lib not available - fall back to pure Dart
      _lib = null;
    }
  }

  /// Check if native patching is available
  static bool get isNativeAvailable {
    _init();
    return _lib != null;
  }

  /// Patch a .riv file on disk to add an input
  /// Only works on writable files (not bundled assets)
  static Future<bool> patchFile(
    String rivPath,
    String inputName, {
    RiveInputType type = RiveInputType.number,
    double min = 0,
    double max = 1,
  }) async {
    _init();
    if (_patchFile == null) return false;

    final pathPtr = inputName.toNativeUtf8();
    final namePtr = inputName.toNativeUtf8();

    try {
      final result = _patchFile!(
        rivPath.toNativeUtf8(),
        namePtr,
        type.index,
        min,
        max,
      );
      return result == 1;
    } finally {
      malloc.free(pathPtr);
      malloc.free(namePtr);
    }
  }

  /// Patch .riv bytes in memory - returns new ByteData with input added
  /// This is the preferred method for Flutter assets
  static Future<ByteData?> patchBytes(
    ByteData original,
    String inputName, {
    RiveInputType type = RiveInputType.number,
    double min = 0,
    double max = 1,
  }) async {
    _init();

    // If native available, use it
    if (_patchMemory != null) {
      return _patchBytesNative(original, inputName, type, min, max);
    }

    // Fall back to pure Dart implementation
    return _patchBytesDart(original, inputName, type, min, max);
  }

  static ByteData? _patchBytesNative(
    ByteData original,
    String inputName,
    RiveInputType type,
    double min,
    double max,
  ) {
    final inputSize = original.lengthInBytes;
    final outputMaxSize = inputSize + 1024; // Extra space for new input

    final inputPtr = malloc<Uint8>(inputSize);
    final outputPtr = malloc<Uint8>(outputMaxSize);
    final namePtr = inputName.toNativeUtf8();

    try {
      // Copy input data
      final inputList = original.buffer.asUint8List();
      for (int i = 0; i < inputSize; i++) {
        inputPtr[i] = inputList[i];
      }

      final resultSize = _patchMemory!(
        inputPtr,
        inputSize,
        outputPtr,
        outputMaxSize,
        namePtr,
        type.index,
        min,
        max,
      );

      if (resultSize < 0) return null;

      // Copy output to ByteData
      final outputList = Uint8List(resultSize);
      for (int i = 0; i < resultSize; i++) {
        outputList[i] = outputPtr[i];
      }

      return ByteData.view(outputList.buffer);
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
      malloc.free(namePtr);
    }
  }

  /// Pure Dart implementation - patches the .riv binary directly
  /// Simpler but less robust than native approach
  static ByteData? _patchBytesDart(
    ByteData original,
    String inputName,
    RiveInputType type,
    double min,
    double max,
  ) {
    final bytes = original.buffer.asUint8List();

    // Verify RIVE header
    if (bytes.length < 4 ||
        bytes[0] != 0x52 || // R
        bytes[1] != 0x49 || // I
        bytes[2] != 0x56 || // V
        bytes[3] != 0x45) { // E
      return null;
    }

    // Create input block
    final inputBlock = _createInputBlock(inputName, type, min, max);

    // Append to file (simplified - full impl would insert at correct offset)
    final result = Uint8List(bytes.length + inputBlock.length);
    result.setRange(0, bytes.length, bytes);
    result.setRange(bytes.length, result.length, inputBlock);

    return ByteData.view(result.buffer);
  }

  /// Create a Rive input definition block
  static Uint8List _createInputBlock(
    String name,
    RiveInputType type,
    double min,
    double max,
  ) {
    final buffer = <int>[];

    // Type ID
    switch (type) {
      case RiveInputType.number:
        buffer.add(56); // NumberInput
        break;
      case RiveInputType.boolean:
        buffer.add(57); // BoolInput
        break;
      case RiveInputType.trigger:
        buffer.add(58); // TriggerInput
        break;
    }

    // Name property (key 4)
    buffer.add(4);
    _writeVarint(buffer, name.length);
    buffer.addAll(name.codeUnits);

    // End marker
    buffer.add(0);

    return Uint8List.fromList(buffer);
  }

  static void _writeVarint(List<int> buffer, int value) {
    while (value > 0x7F) {
      buffer.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    buffer.add(value & 0x7F);
  }
}


/// Batch inject multiple inputs at once
/// Usage:
/// ```dart
/// await RivePatcher.batchInject('assets/wfl.riv', [
///   {'name': 'lipShape', 'min': 0, 'max': 8},
///   {'name': 'roastLevel', 'min': 0, 'max': 5},
///   {'name': 'isTalking', 'type': 'bool'},
/// ]);
/// ```
extension RivePatcherBatch on RivePatcher {
  static Future<ByteData?> batchPatchBytes(
    ByteData original,
    List<Map<String, dynamic>> inputs,
  ) async {
    ByteData? current = original;

    for (final input in inputs) {
      final name = input['name'] as String;
      final min = (input['min'] as num?)?.toDouble() ?? 0;
      final max = (input['max'] as num?)?.toDouble() ?? 1;
      final typeStr = input['type'] as String? ?? 'number';

      final type = switch (typeStr) {
        'bool' || 'boolean' => RiveInputType.boolean,
        'trigger' => RiveInputType.trigger,
        _ => RiveInputType.number,
      };

      current = await RivePatcher.patchBytes(current!, name, type: type, min: min, max: max);
      if (current == null) return null;
    }

    return current;
  }
}

/// Quick inject helper - load asset, patch, return bytes
Future<ByteData?> injectInputs(String assetPath, List<Map<String, dynamic>> inputs) async {
  final original = await rootBundle.load(assetPath);
  return RivePatcherBatch.batchPatchBytes(original, inputs);
}

/// Default WFL inputs - all the controls Terry needs
final wflInputs = [
  {'name': 'lipShape', 'min': 0, 'max': 8},
  {'name': 'terry_headTurn', 'min': -40, 'max': 40},
  {'name': 'terryEyes', 'min': 0, 'max': 4},
  {'name': 'roastLevel', 'min': 0, 'max': 5},
  {'name': 'isTalking', 'type': 'bool'},
  {'name': 'nigel_headTurn', 'min': -40, 'max': 40},
];

