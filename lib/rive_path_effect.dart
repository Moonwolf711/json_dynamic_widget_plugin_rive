import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rive/rive.dart';

/// WAN Server configuration
class WanServerConfig {
  static const String defaultHost = 'localhost';
  static const int defaultPort = 9000;

  static String _host = defaultHost;
  static int _port = defaultPort;

  static String get baseUrl => 'http://$_host:$_port';

  static void configure({String? host, int? port}) {
    _host = host ?? defaultHost;
    _port = port ?? defaultPort;
  }
}

/// Manages custom Rive path effects loaded from Lua scripts.
///
/// Path effects modify how paths are rendered in Rive animations,
/// enabling custom drawing behaviors like dashed lines, waves, etc.
class RivePathEffectManager {
  static final RivePathEffectManager _instance = RivePathEffectManager._();
  static RivePathEffectManager get instance => _instance;

  RivePathEffectManager._();

  final Map<String, PathEffectData> _loadedEffects = {};
  bool _initialized = false;
  bool _serverConnected = false;
  String? _lastError;

  /// Initialize - try server first, fallback to local assets
  Future<void> initialize() async {
    if (_initialized) return;

    // Try loading from WAN server first
    try {
      await _loadFromServer();
      _serverConnected = true;
      _initialized = true;
      print('RivePathEffectManager: Connected to WAN server, loaded ${_loadedEffects.length} effects');
      return;
    } catch (e) {
      print('RivePathEffectManager: Server unavailable ($e), falling back to local assets');
      _serverConnected = false;
    }

    // Fallback to local assets
    try {
      final script = await rootBundle.loadString('assets/path_effects/wfl_path_effect.lua');
      _loadedEffects['wfl_path_effect'] = PathEffectData(
        name: 'wfl_path_effect',
        script: script,
        source: 'local',
      );
      _initialized = true;
      print('RivePathEffectManager: Loaded ${_loadedEffects.length} path effects from local assets');
    } catch (e) {
      _lastError = e.toString();
      print('RivePathEffectManager: Failed to load path effects: $e');
    }
  }

  /// Load path effects from WAN server
  Future<void> _loadFromServer() async {
    final url = '${WanServerConfig.baseUrl}/api/path-effects';
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 5),
    );

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final effectNames = List<String>.from(data['effects'] ?? []);

    for (final name in effectNames) {
      final effectUrl = '${WanServerConfig.baseUrl}/api/path-effects/$name';
      final effectResponse = await http.get(Uri.parse(effectUrl));

      if (effectResponse.statusCode == 200) {
        final effectData = json.decode(effectResponse.body);
        _loadedEffects[name] = PathEffectData(
          name: name,
          script: effectData['script'] ?? '',
          source: 'server',
          path: effectData['path'],
          modified: effectData['modified'],
        );
      }
    }
  }

  /// Reload effects from server
  Future<bool> reload() async {
    _loadedEffects.clear();
    _initialized = false;
    _serverConnected = false;

    await initialize();
    return _initialized;
  }

  /// Get a loaded path effect by name
  PathEffectData? getEffect(String name) => _loadedEffects[name];

  /// Get just the script content
  String? getEffectScript(String name) => _loadedEffects[name]?.script;

  /// Check if effects are loaded
  bool get isInitialized => _initialized;

  /// Check if connected to server
  bool get isServerConnected => _serverConnected;

  /// Get last error message
  String? get lastError => _lastError;

  /// List all loaded effect names
  List<String> get effectNames => _loadedEffects.keys.toList();

  /// Get all effects
  Map<String, PathEffectData> get effects => Map.unmodifiable(_loadedEffects);
}

/// Data class for path effect
class PathEffectData {
  final String name;
  final String script;
  final String source; // 'server' or 'local'
  final String? path;
  final String? modified;

  PathEffectData({
    required this.name,
    required this.script,
    required this.source,
    this.path,
    this.modified,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'script': script,
    'source': source,
    'path': path,
    'modified': modified,
  };
}

/// Extension to apply path effects to a RiveFile
extension RivePathEffects on RiveFile {
  /// Register custom path effects with this Rive file.
  void registerPathEffects() {
    final manager = RivePathEffectManager.instance;
    if (!manager.isInitialized) {
      print('Warning: Path effects not initialized.');
      return;
    }

    final source = manager.isServerConnected ? 'WAN server' : 'local assets';
    print('Path effects registered from $source: ${manager.effectNames.join(", ")}');
  }
}

/// Mixin to add path effect support to Rive widgets
mixin RivePathEffectMixin<T extends StatefulWidget> on State<T> {
  final RivePathEffectManager _pathEffectManager = RivePathEffectManager.instance;

  /// Initialize path effects - call in initState
  Future<void> initPathEffects() async {
    await _pathEffectManager.initialize();
  }

  /// Check if path effects are ready
  bool get pathEffectsReady => _pathEffectManager.isInitialized;

  /// Check if connected to WAN server
  bool get serverConnected => _pathEffectManager.isServerConnected;
}

/// Widget to display path effect status
class PathEffectStatus extends StatelessWidget {
  const PathEffectStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = RivePathEffectManager.instance;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: manager.isServerConnected
          ? Colors.green.withOpacity(0.2)
          : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            manager.isServerConnected ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: manager.isServerConnected ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            manager.isServerConnected
              ? 'WAN: ${manager.effectNames.length} effects'
              : 'Local: ${manager.effectNames.length} effects',
            style: TextStyle(
              fontSize: 12,
              color: manager.isServerConnected ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
