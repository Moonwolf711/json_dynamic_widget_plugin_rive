/// WFL Dev Commands System
/// Allows AI chat to execute live commands to control the app
/// Examples:
/// - "animate terry talking" - Start talking animation
/// - "set terry mouth a" - Change mouth shape
/// - "blink nigel" - Trigger blink animation
library;

import 'package:flutter/material.dart';

/// Command result with success status and optional message
class CommandResult {
  final bool success;
  final String message;
  final dynamic data;

  CommandResult({
    required this.success,
    required this.message,
    this.data,
  });

  factory CommandResult.success(String message, {dynamic data}) {
    return CommandResult(success: true, message: message, data: data);
  }

  factory CommandResult.error(String message) {
    return CommandResult(success: false, message: message);
  }
}

/// Interface for executing dev commands
abstract class DevCommandExecutor {
  /// Animate a character
  Future<CommandResult> animateCharacter(String character, String animation);

  /// Set mouth shape for lip-sync
  Future<CommandResult> setMouthShape(String character, String shape);

  /// Trigger blink
  Future<CommandResult> triggerBlink(String character);

  /// Play sound effect
  Future<CommandResult> playSFX(String sfxName);

  /// Set character scale
  Future<CommandResult> setScale(String character, double scale);

  /// Move character to position
  Future<CommandResult> moveCharacter(String character, double x, double y);

  /// Add custom layer (future feature)
  Future<CommandResult> addLayer(String character, String layerPath);

  /// Execute custom Flutter code (advanced, requires safety checks)
  Future<CommandResult> executeCustomCode(String code);

  /// Get list of available commands
  List<String> getAvailableCommands();

  /// Get current state info
  Map<String, dynamic> getStateInfo();
}

/// Parser for natural language dev commands
class DevCommandParser {
  /// Parse a text command into structured data
  static ParsedCommand? parse(String text) {
    final lower = text.toLowerCase().trim();

    // Animate command: "animate terry talking", "start talking animation for nigel"
    final animateRegex = RegExp(r'(animate|start|play)\s+(terry|nigel)\s+(\w+)');
    final animateMatch = animateRegex.firstMatch(lower);
    if (animateMatch != null) {
      return ParsedCommand(
        type: CommandType.animate,
        target: animateMatch.group(2)!,
        value: animateMatch.group(3)!,
      );
    }

    // Mouth shape: "set terry mouth a", "change nigel mouth to o"
    final mouthRegex = RegExp(r'(set|change)\s+(terry|nigel)\s+mouth\s+(?:to\s+)?(\w+)');
    final mouthMatch = mouthRegex.firstMatch(lower);
    if (mouthMatch != null) {
      return ParsedCommand(
        type: CommandType.mouthShape,
        target: mouthMatch.group(2)!,
        value: mouthMatch.group(3)!,
      );
    }

    // Blink: "blink terry", "make nigel blink"
    final blinkRegex = RegExp(r'(blink|make\s+\w+\s+blink)\s*(terry|nigel)?');
    final blinkMatch = blinkRegex.firstMatch(lower);
    if (blinkMatch != null) {
      return ParsedCommand(
        type: CommandType.blink,
        target: blinkMatch.group(2) ?? 'both',
      );
    }

    // SFX: "play rimshot", "sfx airhorn"
    final sfxRegex = RegExp(r'(play|sfx|sound)\s+(\w+)');
    final sfxMatch = sfxRegex.firstMatch(lower);
    if (sfxMatch != null) {
      return ParsedCommand(
        type: CommandType.playSFX,
        value: sfxMatch.group(2)!,
      );
    }

    // Scale: "scale terry 1.5", "resize nigel to 2.0"
    final scaleRegex = RegExp(r'(scale|resize)\s+(terry|nigel)\s+(?:to\s+)?([0-9.]+)');
    final scaleMatch = scaleRegex.firstMatch(lower);
    if (scaleMatch != null) {
      final scale = double.tryParse(scaleMatch.group(3)!);
      if (scale != null) {
        return ParsedCommand(
          type: CommandType.scale,
          target: scaleMatch.group(2)!,
          value: scale.toString(),
        );
      }
    }

    // Position: "move terry 100 200", "position nigel at 300, 400"
    final posRegex = RegExp(r'(move|position)\s+(terry|nigel)\s+(?:at|to\s+)?([0-9.]+)[,\s]+([0-9.]+)');
    final posMatch = posRegex.firstMatch(lower);
    if (posMatch != null) {
      return ParsedCommand(
        type: CommandType.move,
        target: posMatch.group(2)!,
        value: '${posMatch.group(3)},${posMatch.group(4)}',
      );
    }

    // Add layer: "add layer assets/foo.png to terry"
    final layerRegex = RegExp(r'add\s+layer\s+([\w/.]+)\s+to\s+(terry|nigel)');
    final layerMatch = layerRegex.firstMatch(lower);
    if (layerMatch != null) {
      return ParsedCommand(
        type: CommandType.addLayer,
        target: layerMatch.group(2)!,
        value: layerMatch.group(1)!,
      );
    }

    return null; // No command matched
  }

  /// Get help text for available commands
  static String getHelpText() {
    return '''
🛠️ Available Dev Commands:

**Animations:**
• animate [terry|nigel] [idle|talking|blink|excited]
  Example: "animate terry talking"

**Mouth Shapes (for lip-sync):**
• set [terry|nigel] mouth [a|e|i|o|u|x]
  Example: "set nigel mouth a"

**Blinking:**
• blink [terry|nigel]
  Example: "blink terry"

**Sound Effects:**
• play [sfx_name]
  Available: rimshot, airhorn, drumroll, laugh_track, sad_trombone, whoosh, ding, buzzer
  Example: "play rimshot"

**Scale:**
• scale [terry|nigel] [size]
  Example: "scale terry 1.5"

**Position:**
• move [terry|nigel] [x] [y]
  Example: "move nigel 300 400"

**Layers (Coming Soon):**
• add layer [path] to [terry|nigel]
  Example: "add layer assets/hat.png to terry"

Type any command naturally and I'll execute it!
''';
  }
}

/// Parsed command structure
class ParsedCommand {
  final CommandType type;
  final String? target; // 'terry', 'nigel', 'both', etc.
  final String? value;   // animation name, mouth shape, etc.

  ParsedCommand({
    required this.type,
    this.target,
    this.value,
  });

  @override
  String toString() => 'ParsedCommand($type, target: $target, value: $value)';
}

/// Command types
enum CommandType {
  animate,
  mouthShape,
  blink,
  playSFX,
  scale,
  move,
  addLayer,
  customCode,
  help,
}

/// Widget that shows command execution feedback
class CommandFeedback extends StatelessWidget {
  final CommandResult result;

  const CommandFeedback({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            color: result.success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: result.success ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
