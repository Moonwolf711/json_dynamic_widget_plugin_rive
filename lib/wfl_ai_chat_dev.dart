import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'claude_provider.dart';
import 'wfl_config.dart';
import 'dev_commands.dart';

/// AI Model options
enum AIModel { gemini, claude }

/// WFL AI Chat with Dev Commands - Multi-model chat for the dating show
/// Supports both Gemini (Firebase) and Claude (Anthropic) APIs
/// NOW WITH DEV COMMANDS: Can control animations, mouth shapes, SFX, and more!
class WFLAIChatDev extends StatefulWidget {
  final String? systemPrompt;
  final String title;
  final String? claudeApiKey;
  final DevCommandExecutor? commandExecutor;

  const WFLAIChatDev({
    super.key,
    this.systemPrompt,
    this.title = 'WFL AI Writer + Dev Console',
    this.claudeApiKey,
    this.commandExecutor,
  });

  @override
  State<WFLAIChatDev> createState() => _WFLAIChatDevState();
}

class _WFLAIChatDevState extends State<WFLAIChatDev> {
  late LlmProvider _provider;
  AIModel _selectedModel = AIModel.gemini;
  final List<CommandResult> _commandHistory = [];
  final ScrollController _commandScrollController = ScrollController();

  // Enhanced system prompt with dev commands
  static const String _defaultSystemPrompt = '''You are a comedy writer AND dev assistant for "Wooking for Love", a dating show parody.

The show features two hosts:
- Terry: Young, Gen-Z energy, uses slang like "bruh", "lowkey", "no cap", "fire"
- Nigel: British, refined, dry wit, uses phrases like "rather", "indeed", "curious"

Generate funny roasts, banter, and dating show commentary in their styles.
Keep responses punchy and TV-ready.

**DEV COMMANDS**: You can also execute live commands to control the show! Available commands:
- animate [terry|nigel] [idle|talking|blink|excited] - Start animation
- set [terry|nigel] mouth [a|e|i|o|u|x] - Change mouth shape
- blink [terry|nigel] - Trigger blink
- play [sfx_name] - Play sound effect (rimshot, airhorn, drumroll, laugh_track, sad_trombone, whoosh, ding, buzzer)
- scale [terry|nigel] [size] - Resize character
- move [terry|nigel] [x] [y] - Move character position

When you see a command in user's message, execute it and report results!
Example: User says "Make Terry do a talking animation" → You execute: "animate terry talking"
''';

  @override
  void initState() {
    super.initState();
    _initProvider(_selectedModel);
  }

  void _initProvider(AIModel model) {
    final systemPrompt = widget.systemPrompt ?? _defaultSystemPrompt;

    switch (model) {
      case AIModel.gemini:
        _provider = FirebaseProvider(
          model: FirebaseAI.googleAI().generativeModel(
            model: 'gemini-2.0-flash',
            systemInstruction: Content.system(systemPrompt),
          ),
        );
        break;

      case AIModel.claude:
        final apiKey = widget.claudeApiKey ?? WFLConfig.claudeApiKey;

        if (apiKey.isEmpty) {
          // Fallback to Gemini if no Claude key
          _provider = FirebaseProvider(
            model: FirebaseAI.googleAI().generativeModel(
              model: 'gemini-2.0-flash',
              systemInstruction: Content.system(systemPrompt),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Claude API key not configured, using Gemini instead'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          _provider = ClaudeProvider(
            apiKey: apiKey,
            model: 'claude-3-5-sonnet-20241022', // Latest Claude 3.5 Sonnet
            systemPrompt: systemPrompt,
          );
        }
        break;
    }
  }

  void _switchModel(AIModel newModel) {
    setState(() {
      _selectedModel = newModel;
      _initProvider(newModel);
    });
  }

  /// Process user message and check for dev commands
  Future<void> _processMessage(String message) async {
    // Try to parse as dev command
    final command = DevCommandParser.parse(message);

    if (command != null && widget.commandExecutor != null) {
      // Execute the command
      CommandResult result;

      try {
        switch (command.type) {
          case CommandType.animate:
            result = await widget.commandExecutor!
                .animateCharacter(command.target!, command.value!);
            break;

          case CommandType.mouthShape:
            result = await widget.commandExecutor!
                .setMouthShape(command.target!, command.value!);
            break;

          case CommandType.blink:
            result = await widget.commandExecutor!.triggerBlink(command.target!);
            break;

          case CommandType.playSFX:
            result = await widget.commandExecutor!.playSFX(command.value!);
            break;

          case CommandType.scale:
            final scale = double.tryParse(command.value!) ?? 1.0;
            result = await widget.commandExecutor!.setScale(command.target!, scale);
            break;

          case CommandType.move:
            final parts = command.value!.split(',');
            final x = double.tryParse(parts[0]) ?? 0;
            final y = double.tryParse(parts[1]) ?? 0;
            result =
                await widget.commandExecutor!.moveCharacter(command.target!, x, y);
            break;

          case CommandType.addLayer:
            result = await widget.commandExecutor!
                .addLayer(command.target!, command.value!);
            break;

          case CommandType.help:
            result = CommandResult.success(DevCommandParser.getHelpText());
            break;

          default:
            result = CommandResult.error('Command type not implemented yet');
        }

        // Add to command history
        setState(() {
          _commandHistory.add(result);
          // Auto-scroll to latest command
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_commandScrollController.hasClients) {
              _commandScrollController.animateTo(
                _commandScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        });
      } catch (e) {
        setState(() {
          _commandHistory.add(CommandResult.error('Error: $e'));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            const SizedBox(width: 16),
            // Model selector dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<AIModel>(
                value: _selectedModel,
                dropdownColor: Colors.deepPurple.shade700,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: const [
                  DropdownMenuItem(
                    value: AIModel.gemini,
                    child: Text('🔥 Gemini 2.0'),
                  ),
                  DropdownMenuItem(
                    value: AIModel.claude,
                    child: Text('🤖 Claude 3.5'),
                  ),
                ],
                onChanged: (AIModel? newValue) {
                  if (newValue != null) {
                    _switchModel(newValue);
                  }
                },
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Show dev commands help
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Dev Commands'),
                  content: SingleChildScrollView(
                    child: Text(DevCommandParser.getHelpText()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Show Dev Commands',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _initProvider(_selectedModel);
                _commandHistory.clear();
              });
            },
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Command history panel (collapsible)
          if (_commandHistory.isNotEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: const Border(
                  bottom: BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Command History',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            setState(() {
                              _commandHistory.clear();
                            });
                          },
                          tooltip: 'Clear History',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _commandScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _commandHistory.length,
                      itemBuilder: (context, index) {
                        final result = _commandHistory[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${result.success ? "✓" : "✗"} ${result.message}',
                            style: TextStyle(
                              color: result.success ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Chat view
          Expanded(
            child: LlmChatView(
              provider: _provider,
              welcomeMessage:
                  'Hey! I\'m your WFL comedy writer + dev console powered by '
                  '${_selectedModel == AIModel.gemini ? "Gemini 2.0 Flash" : "Claude 3.5 Sonnet"}.\n\n'
                  '💬 Ask me for roasts, dating show banter, or contestant jokes!\n'
                  '🛠️ I can also execute dev commands - type code icon above for help!',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commandScrollController.dispose();
    super.dispose();
  }
}

/// Quick dialog to show AI chat in a popup
class WFLAIChatDevDialog extends StatelessWidget {
  final DevCommandExecutor? commandExecutor;

  const WFLAIChatDevDialog({super.key, this.commandExecutor});

  static Future<void> show(BuildContext context,
      {DevCommandExecutor? commandExecutor}) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 600,
          height: 700,
          child: WFLAIChatDev(
            commandExecutor: commandExecutor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WFLAIChatDev(
      commandExecutor: commandExecutor,
    );
  }
}
