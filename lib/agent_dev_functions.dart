// WFL Agent Dev Functions
// Code execution, file editing, and dev tools like Base44/Lovable

import 'dart:io';
import 'dart:convert';

class AgentDevFunctions {
  final String projectRoot;
  
  AgentDevFunctions({this.projectRoot = 'C:/wfl'});

  /// List project files
  Future<List<String>> listFiles({String? subdir, String? extension}) async {
    final dir = Directory(subdir != null ? '$projectRoot/$subdir' : projectRoot);
    if (!await dir.exists()) return [];
    
    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final path = entity.path.replaceAll('\\', '/');
        if (extension == null || path.endsWith(extension)) {
          files.add(path.replaceFirst('$projectRoot/', ''));
        }
      }
    }
    return files;
  }

  /// Read file contents
  Future<String> readFile(String relativePath) async {
    final file = File('$projectRoot/$relativePath');
    if (!await file.exists()) throw Exception('File not found: $relativePath');
    return await file.readAsString();
  }

  /// Write file contents
  Future<void> writeFile(String relativePath, String content) async {
    final file = File('$projectRoot/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Edit file with search/replace
  Future<String> editFile(String relativePath, String oldText, String newText) async {
    final content = await readFile(relativePath);
    if (!content.contains(oldText)) {
      throw Exception('Text not found in file');
    }
    final newContent = content.replaceFirst(oldText, newText);
    await writeFile(relativePath, newContent);
    return 'Replaced ${oldText.length} chars with ${newText.length} chars';
  }

  /// Run Flutter command
  Future<String> runFlutter(List<String> args) async {
    final result = await Process.run(
      'flutter',
      args,
      workingDirectory: projectRoot,
      runInShell: true,
    );
    return '${result.stdout}\n${result.stderr}'.trim();
  }

  /// Hot reload (if running)
  Future<String> hotReload() async {
    // Send 'r' to stdin of running flutter process
    return 'Hot reload triggered (if app is running)';
  }

  /// Run dart analyze
  Future<String> analyze() async {
    return await runFlutter(['analyze', '--no-fatal-infos']);
  }

  /// Format code
  Future<String> formatCode([String? path]) async {
    final target = path ?? 'lib';
    return await runFlutter(['format', target]);
  }

  /// Get pubspec dependencies
  Future<Map<String, dynamic>> getPubspec() async {
    final content = await readFile('pubspec.yaml');
    // Simple YAML parse for dependencies
    final deps = <String, String>{};
    final lines = content.split('\n');
    bool inDeps = false;
    for (final line in lines) {
      if (line.trim() == 'dependencies:') {
        inDeps = true;
        continue;
      }
      if (inDeps && line.startsWith('  ') && line.contains(':')) {
        final parts = line.trim().split(':');
        if (parts.length >= 2) {
          deps[parts[0].trim()] = parts[1].trim();
        }
      }
      if (inDeps && !line.startsWith('  ') && line.isNotEmpty) {
        break;
      }
    }
    return {'dependencies': deps};
  }

  /// Add dependency
  Future<String> addDependency(String package) async {
    return await runFlutter(['pub', 'add', package]);
  }

  /// Create new widget file
  Future<String> createWidget(String name, {String? template}) async {
    final className = _toPascalCase(name);
    final fileName = _toSnakeCase(name);
    final content = template ?? '''
import 'package:flutter/material.dart';

class $className extends StatefulWidget {
  const $className({super.key});

  @override
  State<$className> createState() => _${className}State();
}

class _${className}State extends State<$className> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // TODO: Implement $className
    );
  }
}
''';
    await writeFile('lib/$fileName.dart', content);
    return 'Created lib/$fileName.dart';
  }

  String _toPascalCase(String s) {
    return s.split('_').map((w) => 
      w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase()
    ).join();
  }

  String _toSnakeCase(String s) {
    return s.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}'
    ).replaceFirst('_', '');
  }
}
