// WFL Agent Chat - AI-powered development assistant
// Allows prompting changes directly within the app like Base44/Lovable

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'agent_api_config.dart';
import 'agent_api_client.dart';
import 'agent_settings_dialog.dart';
import 'agent_dev_functions.dart';
import 'agent_bmad_system.dart';
import 'permission_dialog.dart';

/// Chat message model
class ChatMessage {
  final String role; // 'user', 'assistant', 'system', 'command'
  final String content;
  final DateTime timestamp;
  final bool isCommand;
  final String? commandResult;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isCommand = false,
    this.commandResult,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Command handler callback
typedef CommandHandler = Future<String> Function(String command, List<String> args);

/// Agent chat configuration
class AgentChatConfig {
  // Animation controls
  final void Function(double)? setMouthShape;
  final void Function(double)? setHeadTurn;
  final void Function(double)? setEyeState;
  final void Function(double)? setRoastTone;
  final void Function(bool)? setTalking;
  final void Function()? resetPose;

  // Playback controls
  final void Function()? play;
  final void Function()? pause;
  final void Function()? stop;

  // View controls
  final void Function()? toggleBoneEditor;
  final void Function()? toggleFullscreen;
  final void Function()? zoomIn;
  final void Function()? zoomOut;

  // File operations
  final void Function()? saveProject;
  final void Function()? exportVideo;
  final void Function()? openProject;

  // Settings
  final void Function()? openSettings;

  // State getters
  final double Function()? getMouthShape;
  final double Function()? getHeadTurn;
  final double Function()? getEyeState;
  final double Function()? getRoastTone;
  final bool Function()? isTalking;
  final bool Function()? isPlaying;

  const AgentChatConfig({
    this.setMouthShape,
    this.setHeadTurn,
    this.setEyeState,
    this.setRoastTone,
    this.setTalking,
    this.resetPose,
    this.play,
    this.pause,
    this.stop,
    this.toggleBoneEditor,
    this.toggleFullscreen,
    this.zoomIn,
    this.zoomOut,
    this.saveProject,
    this.exportVideo,
    this.openProject,
    this.openSettings,
    this.getMouthShape,
    this.getHeadTurn,
    this.getEyeState,
    this.getRoastTone,
    this.isTalking,
    this.isPlaying,
  });
}

class WFLAgentChat extends StatefulWidget {
  final AgentChatConfig config;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const WFLAgentChat({
    super.key,
    required this.config,
    this.isExpanded = true,
    this.onToggleExpand,
  });

  @override
  State<WFLAgentChat> createState() => WFLAgentChatState();
}

class WFLAgentChatState extends State<WFLAgentChat> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _useAI = true;
  
  // API system
  final AgentAPIConfig _apiConfig = AgentAPIConfig();
  late final AgentAPIClient _apiClient;
  final AgentDevFunctions _devFunctions = AgentDevFunctions();

  // BMad multi-agent system
  late final BMadAgentSystem _bmadSystem;
  bool _useMultiAgent = true;  // Enable BMad multi-agent by default

  // Permission settings
  bool _applyForAll = false;
  bool _skipPermissions = false;
  String? _lastCodeBlock;  // Store last generated code for apply

  // Auto-run modes
  bool _autoRun = false;           // Auto-apply generated code
  bool _runUntilContextOut = false; // Keep running until context exhausted
  int _autoRunCount = 0;           // Track auto-run iterations
  static const int _maxAutoRuns = 10; // Safety limit

  // External prompt file watcher (for Claude Code integration)
  static const String _promptFilePath = 'C:\\wfl\\agent_prompt.txt';
  Timer? _fileWatchTimer;
  String _lastPromptContent = '';
  final bool _autoSubmitExternal = true;  // Auto-submit prompts from file

  @override
  void initState() {
    super.initState();
    _apiClient = AgentAPIClient(_apiConfig);
    _bmadSystem = BMadAgentSystem(
      config: _apiConfig,
      onLog: (msg) => debugPrint('[BMad] $msg'),
      onAgentStart: (agent, task) {
        _addSystemMessage('[${agent.name}] Starting...');
      },
      onAgentComplete: (result) {
        if (result.commands != null && result.commands!.isNotEmpty) {
          // Auto-execute commands from agents
          for (final cmd in result.commands!) {
            if (cmd.startsWith('/')) {
              _executeCommand(cmd);
            }
          }
        }
      },
    );
    _initAPI();
    _startFileWatcher();
    _addSystemMessage('''Welcome to WFL Agent with BMad multi-agent system!

**Quick Commands:**
- `/mouth`, `/head`, `/eyes` - Animation
- `/play`, `/pause`, `/stop` - Playback
- `/bones` - Edit mode
- `/agents` - Toggle multi-agent AI
- `/help` - Full command list

**Multi-Agent Mode (ON):**
Just describe what you want - specialized agents will work in parallel:
- Animator, Developer, Debugger, Designer, Tester...

Try: "make the mouth animate while talking" or "add a volume slider"

**Claude Code Integration:** Prompts auto-received from agent_prompt.txt''');
  }

  Future<void> _initAPI() async {
    await _apiConfig.load();
    setState(() {});
  }

  /// Start watching for external prompts from Claude Code
  void _startFileWatcher() {
    // Check the prompt file every 500ms
    _fileWatchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkPromptFile();
    });
    debugPrint('FileWatcher: Monitoring $_promptFilePath');
  }

  /// Check if prompt file has new content
  Future<void> _checkPromptFile() async {
    try {
      final file = File(_promptFilePath);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty || content == _lastPromptContent) return;

      // New prompt detected!
      _lastPromptContent = content;
      debugPrint('FileWatcher: New prompt detected: ${content.substring(0, content.length.clamp(0, 50))}...');

      // Clear the file immediately to prevent re-processing
      await file.writeAsString('');

      // Populate the text field
      setState(() {
        _inputController.text = content.trim();
      });

      // Auto-submit if enabled
      if (_autoSubmitExternal && !_isProcessing) {
        _addSystemMessage('Received prompt from Claude Code');
        await _handleSubmit();
      }
    } catch (e) {
      // Silently ignore file errors (file might be locked, etc.)
      debugPrint('FileWatcher error: $e');
    }
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AgentSettingsDialog(
        config: _apiConfig,
        onSave: () => setState(() {}),
      ),
    );
  }

  void _addSystemMessage(String content) {
    setState(() {
      _messages.add(ChatMessage(role: 'system', content: content));
    });
  }

  void _addUserMessage(String content) {
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: content));
    });
    _scrollToBottom();
  }

  void _addAssistantMessage(String content, {bool isError = false}) {
    setState(() {
      _messages.add(ChatMessage(role: 'assistant', content: content, isError: isError));
    });
    _scrollToBottom();
  }

  void _addCommandResult(String command, String result, {bool isError = false}) {
    setState(() {
      _messages.add(ChatMessage(
        role: 'command',
        content: command,
        isCommand: true,
        commandResult: result,
        isError: isError,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _isProcessing) return;

    _inputController.clear();
    _addUserMessage(input);

    setState(() => _isProcessing = true);

    try {
      if (input.startsWith('/')) {
        // Command mode
        await _executeCommand(input);
      } else if (_useAI) {
        // AI mode
        await _processWithAI(input);
      } else {
        _addAssistantMessage('AI mode is disabled. Use commands starting with / or enable AI mode.');
      }
    } catch (e) {
      _addAssistantMessage('Error: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeCommand(String input) async {
    final parts = input.substring(1).split(' ');
    final command = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    String result;
    bool isError = false;

    switch (command) {
      case 'mouth':
      case 'm':
        if (args.isEmpty) {
          result = 'Current mouth shape: ${widget.config.getMouthShape?.call() ?? 0}';
        } else {
          final value = double.tryParse(args[0]) ?? 0;
          widget.config.setMouthShape?.call(value.clamp(0, 8));
          result = 'Mouth shape set to $value';
        }
        break;

      case 'head':
      case 'h':
        if (args.isEmpty) {
          result = 'Current head turn: ${widget.config.getHeadTurn?.call() ?? 0}';
        } else {
          final value = double.tryParse(args[0]) ?? 0;
          widget.config.setHeadTurn?.call(value.clamp(-45, 45));
          result = 'Head turn set to $value degrees';
        }
        break;

      case 'eyes':
      case 'e':
        if (args.isEmpty) {
          result = 'Current eye state: ${widget.config.getEyeState?.call() ?? 0}';
        } else {
          final value = double.tryParse(args[0]) ?? 0;
          widget.config.setEyeState?.call(value.clamp(0, 4));
          result = 'Eye state set to $value';
        }
        break;

      case 'tone':
      case 't':
        if (args.isEmpty) {
          result = 'Current roast tone: ${widget.config.getRoastTone?.call() ?? 0}';
        } else {
          final value = double.tryParse(args[0]) ?? 0;
          widget.config.setRoastTone?.call(value.clamp(0, 3));
          result = 'Roast tone set to $value';
        }
        break;

      case 'talk':
        if (args.isEmpty) {
          result = 'Currently talking: ${widget.config.isTalking?.call() ?? false}';
        } else {
          final on = args[0].toLowerCase() == 'on' || args[0] == '1' || args[0] == 'true';
          widget.config.setTalking?.call(on);
          result = 'Talking ${on ? "enabled" : "disabled"}';
        }
        break;

      case 'play':
        widget.config.play?.call();
        result = 'Playing animation';
        break;

      case 'pause':
        widget.config.pause?.call();
        result = 'Animation paused';
        break;

      case 'stop':
        widget.config.stop?.call();
        result = 'Animation stopped';
        break;

      case 'reset':
        widget.config.resetPose?.call();
        result = 'Pose reset to default';
        break;

      case 'bones':
        widget.config.toggleBoneEditor?.call();
        result = 'Bone editor toggled';
        break;

      case 'fullscreen':
      case 'fs':
        widget.config.toggleFullscreen?.call();
        result = 'Fullscreen toggled';
        break;

      case 'zoomin':
      case 'zi':
        widget.config.zoomIn?.call();
        result = 'Zoomed in';
        break;

      case 'zoomout':
      case 'zo':
        widget.config.zoomOut?.call();
        result = 'Zoomed out';
        break;

      case 'save':
        widget.config.saveProject?.call();
        result = 'Project saved';
        break;

      case 'export':
        widget.config.exportVideo?.call();
        result = 'Export started';
        break;

      case 'open':
        widget.config.openProject?.call();
        result = 'Open project dialog';
        break;

      case 'settings':
        _openSettings();
        result = 'Settings dialog opened';
        break;

      case 'status':
        result = '''Current state:
- Mouth: ${widget.config.getMouthShape?.call() ?? 'N/A'}
- Head: ${widget.config.getHeadTurn?.call() ?? 'N/A'}
- Eyes: ${widget.config.getEyeState?.call() ?? 'N/A'}
- Tone: ${widget.config.getRoastTone?.call() ?? 'N/A'}
- Talking: ${widget.config.isTalking?.call() ?? 'N/A'}
- Playing: ${widget.config.isPlaying?.call() ?? 'N/A'}''';
        break;

      case 'ai':
        if (args.isEmpty) {
          result = 'AI mode is ${_useAI ? "enabled" : "disabled"}';
        } else {
          final on = args[0].toLowerCase() == 'on' || args[0] == '1' || args[0] == 'true';
          setState(() => _useAI = on);
          result = 'AI mode ${on ? "enabled" : "disabled"}';
        }
        break;

      case 'agents':
      case 'multiagent':
      case 'bmad':
        if (args.isEmpty) {
          result = '''Multi-agent mode: ${_useMultiAgent ? "ENABLED" : "disabled"}

When enabled, your requests are analyzed and split across specialized agents:
- **Orchestrator**: Routes tasks to appropriate agents
- **Animator**: Controls Rive animations
- **Developer**: Writes/modifies code
- **Debugger**: Analyzes and fixes bugs
- **Designer**: UI/UX suggestions
- **Tester**: Generates tests
- **Documenter**: Creates documentation
- **Refactorer**: Improves code structure

All agents run synchronously (in parallel) for faster results.''';
        } else {
          final on = args[0].toLowerCase() == 'on' || args[0] == '1' || args[0] == 'true';
          setState(() => _useMultiAgent = on);
          result = 'Multi-agent mode ${on ? "ENABLED" : "disabled"}';
        }
        break;

      case 'clear':
        setState(() => _messages.clear());
        _addSystemMessage('Chat cleared. Type /help for commands.');
        return;

      case 'help':
      case '?':
        result = '''**Available Commands:**

**Animation:**
- `/mouth <0-8>` or `/m` - Set mouth shape (0=neutral, 1=A, 2=E, etc.)
- `/head <-45 to 45>` or `/h` - Turn head (degrees)
- `/eyes <0-4>` or `/e` - Set eye state
- `/tone <0-3>` or `/t` - Set roast intensity
- `/talk <on/off>` - Toggle talking animation
- `/reset` - Reset all to default

**Playback:**
- `/play` - Start animation
- `/pause` - Pause animation
- `/stop` - Stop animation

**View:**
- `/bones` - Toggle bone editor
- `/fullscreen` or `/fs` - Toggle fullscreen
- `/zoomin` or `/zi` - Zoom in
- `/zoomout` or `/zo` - Zoom out

**File:**
- `/save` - Save project
- `/export` - Export video
- `/open` - Open project

**System:**
- `/status` - Show current state
- `/ai <on/off>` - Toggle AI mode
- `/agents` - Toggle BMad multi-agent mode
- `/settings` - API configuration
- `/clear` - Clear chat
- `/help` - Show this help

**Dev Functions:**
- `/files [dir]` - List project files
- `/read <file>` - Read file contents
- `/edit <file>` - Edit file (AI-assisted)
- `/create <name>` - Create new widget
- `/analyze` - Run dart analyze
- `/format` - Format code
- `/deps` - Show dependencies
- `/add <package>` - Add dependency

**Natural Language:**
Just type normally to use AI assistance!''';
        break;

      // === DEV COMMANDS ===
      case 'files':
      case 'ls':
        try {
          final dir = args.isNotEmpty ? args.join(' ') : null;
          final files = await _devFunctions.listFiles(subdir: dir, extension: '.dart');
          result = files.take(20).join('\n');
          if (files.length > 20) result += '\n... and ${files.length - 20} more';
        } catch (e) {
          result = 'Error: $e';
          isError = true;
        }
        break;

      case 'read':
      case 'cat':
        if (args.isEmpty) {
          result = 'Usage: /read <file>';
          isError = true;
        } else {
          try {
            final content = await _devFunctions.readFile(args.join(' '));
            result = '```dart\n${content.substring(0, content.length.clamp(0, 2000))}${content.length > 2000 ? '\n... truncated' : ''}\n```';
          } catch (e) {
            result = 'Error: $e';
            isError = true;
          }
        }
        break;

      case 'create':
        if (args.isEmpty) {
          result = 'Usage: /create <widget_name>';
          isError = true;
        } else {
          try {
            result = await _devFunctions.createWidget(args[0]);
          } catch (e) {
            result = 'Error: $e';
            isError = true;
          }
        }
        break;

      case 'analyze':
        try {
          _addAssistantMessage('Running dart analyze...');
          result = await _devFunctions.analyze();
        } catch (e) {
          result = 'Error: $e';
          isError = true;
        }
        break;

      case 'format':
      case 'fmt':
        try {
          result = await _devFunctions.formatCode(args.isNotEmpty ? args[0] : null);
        } catch (e) {
          result = 'Error: $e';
          isError = true;
        }
        break;

      case 'deps':
        try {
          final pubspec = await _devFunctions.getPubspec();
          final deps = pubspec['dependencies'] as Map<String, String>;
          result = deps.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        } catch (e) {
          result = 'Error: $e';
          isError = true;
        }
        break;

      case 'add':
        if (args.isEmpty) {
          result = 'Usage: /add <package>';
          isError = true;
        } else {
          try {
            _addAssistantMessage('Adding ${args[0]}...');
            result = await _devFunctions.addDependency(args[0]);
          } catch (e) {
            result = 'Error: $e';
            isError = true;
          }
        }
        break;

      default:
        result = 'Unknown command: $command. Type /help for available commands.';
        isError = true;
    }

    _addCommandResult('/$command ${args.join(" ")}', result, isError: isError);
  }

  Future<void> _processWithAI(String input) async {
    // Get current app state for context
    final appState = {
      'mouth': widget.config.getMouthShape?.call() ?? 0,
      'head': widget.config.getHeadTurn?.call() ?? 0,
      'eyes': widget.config.getEyeState?.call() ?? 0,
      'tone': widget.config.getRoastTone?.call() ?? 0,
      'talking': widget.config.isTalking?.call() ?? false,
    };

    if (_useMultiAgent) {
      // Use BMad multi-agent system
      await _processWithMultiAgent(input, appState);
    } else {
      // Use single agent mode
      await _processWithSingleAgent(input, appState);
    }
  }

  /// Process with BMad multi-agent system (parallel execution)
  Future<void> _processWithMultiAgent(String input, Map<String, dynamic> appState) async {
    final lowerInput = input.toLowerCase().trim();

    // Check if user wants to apply last code
    if (lowerInput == 'apply' || lowerInput == 'yes' || lowerInput == 'y') {
      if (_lastCodeBlock != null && _lastCodeBlock!.isNotEmpty) {
        await _applyCodeWithPermission(_lastCodeBlock!);
        return;
      } else {
        _addAssistantMessage('No code to apply. Ask me to create something first, like "create a button widget"');
        return;
      }
    }

    try {
      _addSystemMessage('Running multi-agent analysis...');

      final results = await _bmadSystem.processRequest(input, appState: appState);

      // Format and display results
      final output = _bmadSystem.formatResults(results);
      _addAssistantMessage(output);

      // Extract and store code blocks for potential apply
      for (final result in results) {
        // Try multiple code block formats
        final patterns = [
          RegExp(r'```dart:?[^\n]*\n([\s\S]*?)```'),  // ```dart or ```dart:filename
          RegExp(r'```flutter\n([\s\S]*?)```'),       // ```flutter
          RegExp(r'```\n(class \w+[\s\S]*?)```'),     // ``` with class definition
        ];

        for (final pattern in patterns) {
          final codeMatch = pattern.firstMatch(result.output);
          if (codeMatch != null) {
            final code = codeMatch.group(1)?.trim();
            if (code != null && code.contains('class ') && code.length > 50) {
              _lastCodeBlock = code;
              debugPrint('Code block stored: ${code.substring(0, 50.clamp(0, code.length))}...');
              debugPrint('Auto-run state: $_autoRun, Loop: $_runUntilContextOut, Skip: $_skipPermissions, Count: $_autoRunCount');

              // Auto-run mode: automatically apply the code
              if (_autoRun) {
                _autoRunCount++;
                _addSystemMessage('Auto-applying code (run $_autoRunCount/$_maxAutoRuns)...');
                await _applyCode(code);

                // Continue running if loop mode is enabled
                if (_runUntilContextOut && _autoRunCount < _maxAutoRuns) {
                  _addSystemMessage('Loop mode: Iteration $_autoRunCount complete. Asking AI what\'s next...');

                  // Small delay to let UI update
                  await Future.delayed(const Duration(milliseconds: 500));

                  // Ask AI what to do next - force code generation
                  final nextPrompt = '''Create the next useful Flutter widget for this animation app.

Pick ONE from this list and OUTPUT THE FULL DART CODE:
- EmotionPreset widget (buttons for happy/sad/angry/surprised expressions)
- VoiceMeter widget (visual audio level indicator)
- AnimationTimeline widget (horizontal timeline with keyframes)
- ExpressionSlider widget (labeled slider for face controls)
- QuickPose widget (grid of preset pose buttons)

IMPORTANT: Output complete Flutter/Dart code in a ```dart code block. Do NOT just describe - write the actual widget code.''';

                  await _processWithMultiAgent(nextPrompt, appState);
                }
              } else {
                _addAssistantMessage('**Code ready!** Type `apply` to create the file, or copy manually.');
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      // Fall back to single agent on error
      _addSystemMessage('Multi-agent failed, using single agent...');
      await _processWithSingleAgent(input, appState);
    }
  }

  /// Apply code with permission dialog
  Future<void> _applyCodeWithPermission(String code) async {
    // Skip dialog if user chose to skip permissions
    if (_skipPermissions) {
      await _applyCode(code);
      return;
    }

    // Skip dialog if apply for all is enabled
    if (_applyForAll) {
      await _applyCode(code);
      return;
    }

    // Show permission dialog
    final result = await PermissionDialog.show(
      context,
      title: 'Apply Code Changes',
      message: 'The AI generated code that will be written to a new file. Review the code below before applying.',
      codePreview: code.length > 500 ? '${code.substring(0, 500)}...' : code,
    );

    if (result == null || !result.approved) {
      _addSystemMessage('Apply cancelled.');
      return;
    }

    // Update permission settings
    if (result.applyForAll) {
      setState(() => _applyForAll = true);
      _addSystemMessage('Apply for all enabled for this session.');
    }
    if (result.skipPermissions) {
      setState(() => _skipPermissions = true);
      _addSystemMessage('⚠️ Dangerous mode: Skipping all permissions.');
    }

    await _applyCode(code);
  }

  /// Actually apply the code to a file
  Future<void> _applyCode(String code) async {
    try {
      // Extract class name from code
      final classMatch = RegExp(r'class\s+(\w+)').firstMatch(code);
      final className = classMatch?.group(1) ?? 'GeneratedWidget';
      final fileName = _toSnakeCase(className);

      // Write to file
      await _devFunctions.writeFile('lib/$fileName.dart', code);
      _addCommandResult('/create $fileName', 'Created lib/$fileName.dart');
      _lastCodeBlock = null;
    } catch (e) {
      _addAssistantMessage('Failed to apply code: $e', isError: true);
    }
  }

  String _toSnakeCase(String s) {
    return s.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}'
    ).replaceFirst('_', '');
  }

  /// Process with single agent (original mode)
  Future<void> _processWithSingleAgent(String input, Map<String, dynamic> appState) async {
    final context = '''You are WFL Agent, an AI dev assistant in the WFL Animator Flutter app.
You help control animations AND write/edit code like Base44 or Lovable.

Current animation state:
- Mouth: ${appState['mouth']}, Head: ${appState['head']}
- Eyes: ${appState['eyes']}, Tone: ${appState['tone']}
- Talking: ${appState['talking']}

Animation commands: /mouth <0-8>, /head <-45 to 45>, /eyes <0-4>, /tone <0-3>
Playback: /play, /pause, /stop, /reset
View: /bones, /fullscreen, /save, /export

Dev commands:
- /files [dir] - List .dart files
- /read <file> - Read file contents
- /create <name> - Create widget
- /analyze - Run dart analyze
- /format - Format code
- /deps - Show dependencies
- /add <pkg> - Add package
- /settings - API config

When users ask to:
- Control animation → suggest appropriate /command
- Edit code → use /read to show file, then provide code changes
- Create features → break down into steps, suggest /create for new widgets
- Debug → suggest /analyze, help interpret errors

Be concise. Suggest commands in backticks. Help write Flutter/Dart code.''';

    try {
      final response = await _apiClient.chat(context, input);
      _addAssistantMessage(response);

      final commandMatch = RegExp(r'`(/\w+[^`]*)`').firstMatch(response);
      if (commandMatch != null) {
        final suggestedCommand = commandMatch.group(1)!;
        _addAssistantMessage('Run `$suggestedCommand`? Type it to execute.');
      }
    } catch (e) {
      _addAssistantMessage('AI error: $e\n\nUse /settings to configure API keys.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isExpanded ? 350 : 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          left: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: widget.isExpanded ? _buildExpandedChat() : _buildCollapsedChat(),
    );
  }

  Widget _buildCollapsedChat() {
    return Column(
      children: [
        IconButton(
          onPressed: widget.onToggleExpand,
          icon: const Icon(Icons.chat, color: Colors.white70),
          tooltip: 'Open Agent Chat',
        ),
        const RotatedBox(
          quarterTurns: 1,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'AGENT',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedChat() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D30),
            border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'WFL Agent',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // AI toggle
              Tooltip(
                message: 'AI Mode: ${_useAI ? "ON" : "OFF"}',
                child: IconButton(
                  onPressed: () => setState(() => _useAI = !_useAI),
                  icon: Icon(
                    _useAI ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                    color: _useAI ? Colors.amber : Colors.grey,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
              // Settings button
              Tooltip(
                message: 'API Settings',
                child: IconButton(
                  onPressed: _openSettings,
                  icon: Icon(
                    Icons.tune,
                    color: _apiConfig.hasPremiumKey ? Colors.green : Colors.grey,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
              IconButton(
                onPressed: widget.onToggleExpand,
                icon: const Icon(Icons.chevron_right, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Collapse',
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) => _buildMessage(_messages[index]),
          ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D30),
            border: Border(top: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _useAI ? 'Ask anything or type /command...' : 'Type /command...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF3C3C3C),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _handleSubmit(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isProcessing ? null : _handleSubmit,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                          )
                        : const Icon(Icons.send, size: 20),
                    color: Colors.blue,
                    tooltip: 'Send',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Control buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildToggleChip(
                    label: 'Auto Run',
                    icon: Icons.play_circle_outline,
                    isActive: _autoRun,
                    activeColor: Colors.green,
                    tooltip: 'Auto-apply generated code without confirmation',
                    onTap: () => setState(() {
                      _autoRun = !_autoRun;
                      if (_autoRun) {
                        _skipPermissions = true;
                        _autoRunCount = 0;  // Reset counter
                      }
                    }),
                  ),
                  _buildToggleChip(
                    label: 'Loop',
                    icon: Icons.loop,
                    isActive: _runUntilContextOut,
                    activeColor: Colors.orange,
                    tooltip: 'Run until context exhausted (max $_maxAutoRuns)',
                    onTap: () => setState(() {
                      _runUntilContextOut = !_runUntilContextOut;
                      if (_runUntilContextOut) {
                        _autoRun = true;
                        _skipPermissions = true;
                        _autoRunCount = 0;  // Reset counter
                      }
                    }),
                  ),
                  _buildToggleChip(
                    label: 'Danger',
                    icon: Icons.warning_amber,
                    isActive: _skipPermissions,
                    activeColor: Colors.red,
                    tooltip: 'Skip all permission dialogs',
                    onTap: () => setState(() {
                      _skipPermissions = !_skipPermissions;
                      if (!_skipPermissions) {
                        _autoRun = false;  // Turn off auto-run when permissions re-enabled
                        _runUntilContextOut = false;
                      }
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(
              color: isActive ? activeColor : Colors.grey.shade600,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? activeColor : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : Colors.grey,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    Color bgColor;
    Color textColor = Colors.white;
    IconData? icon;
    String? prefix;

    switch (message.role) {
      case 'user':
        bgColor = const Color(0xFF264F78);
        icon = Icons.person;
        prefix = 'You';
        break;
      case 'assistant':
        bgColor = message.isError ? const Color(0xFF5D2626) : const Color(0xFF2D4A2D);
        icon = Icons.smart_toy;
        prefix = 'Agent';
        break;
      case 'system':
        bgColor = const Color(0xFF3C3C3C);
        textColor = Colors.white70;
        icon = Icons.info_outline;
        prefix = 'System';
        break;
      case 'command':
        bgColor = const Color(0xFF1E3A5F);
        icon = Icons.terminal;
        prefix = 'Command';
        break;
      default:
        bgColor = const Color(0xFF3C3C3C);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: textColor.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
              ],
              Text(
                prefix ?? '',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (message.isCommand) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                message.content,
                style: const TextStyle(
                  color: Colors.cyan,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            if (message.commandResult != null) ...[
              const SizedBox(height: 6),
              Text(
                message.commandResult!,
                style: TextStyle(
                  color: message.isError ? Colors.red.shade300 : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ] else
            SelectableText(
              message.content,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fileWatchTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
