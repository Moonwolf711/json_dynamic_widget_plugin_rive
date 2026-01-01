/// Stub implementations for record and permission_handler packages
/// Used when building for platforms that don't support these packages

// Stub for AudioRecorder
class AudioRecorder {
  Future<bool> hasPermission() async => false;
  Future<void> start(RecordConfig config, {required String path}) async {}
  Future<String?> stop() async => null;
  void dispose() {}
}

// Stub for RecordConfig
class RecordConfig {
  final AudioEncoder encoder;
  const RecordConfig({this.encoder = AudioEncoder.aacLc});
}

// Stub for AudioEncoder
enum AudioEncoder { aacLc, wav, flac }

// Stub for Permission
class _PermissionRequest {
  Future<PermissionStatus> get status async => PermissionStatus.denied;
  Future<PermissionStatus> request() async => PermissionStatus.denied;
}

class Permission {
  static final microphone = _PermissionRequest();
}

// Stub for PermissionStatus
enum PermissionStatus {
  denied,
  granted,
  permanentlyDenied,
  restricted,
  limited;

  bool get isGranted => this == PermissionStatus.granted;
  bool get isDenied => this == PermissionStatus.denied;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
}

// Stub for openAppSettings
Future<bool> openAppSettings() async => false;
