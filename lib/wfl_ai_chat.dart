import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// WFL AI Chat - Gemini-powered chat for the dating show
/// Can be used for:
/// - Generating roasts/jokes
/// - Character dialogue suggestions
/// - Contestant banter ideas
class WFLAIChat extends StatefulWidget {
  final String? systemPrompt;
  final String title;

  const WFLAIChat({
    super.key,
    this.systemPrompt,
    this.title = 'WFL AI Writer',
  });

  @override
  State<WFLAIChat> createState() => _WFLAIChatState();
}

class _WFLAIChatState extends State<WFLAIChat> {
  late final FirebaseProvider _provider;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  void _initProvider() {
    // Default system prompt for WFL comedy style
    final systemPrompt = widget.systemPrompt ??
        '''You are a comedy writer for "Wooking for Love", a dating show parody.
The show features two hosts:
- Terry: Young, Gen-Z energy, uses slang like "bruh", "lowkey", "no cap", "fire"
- Nigel: British, refined, dry wit, uses phrases like "rather", "indeed", "curious"

Generate funny roasts, banter, and dating show commentary in their styles.
Keep responses punchy and TV-ready.''';

    _provider = FirebaseProvider(
      model: FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
        systemInstruction: Content.system(systemPrompt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _initProvider();
              });
            },
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: LlmChatView(
        provider: _provider,
        welcomeMessage: 'Hey! I\'m your WFL comedy writer. Ask me for roasts, '
            'dating show banter, or contestant jokes!',
      ),
    );
  }
}

/// Quick dialog to show AI chat in a popup
class WFLAIChatDialog extends StatelessWidget {
  const WFLAIChatDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const Dialog(
        child: SizedBox(
          width: 500,
          height: 600,
          child: WFLAIChat(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const WFLAIChat();
  }
}

/// Standalone roast generator using Gemini
class WFLRoastGenerator {
  static final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.0-flash',
  );

  /// Generate a Terry-style roast
  static Future<String> generateTerryRoast(String topic) async {
    final response = await _model.generateContent([
      Content.text(
          'Generate a short, punchy roast about "$topic" in Terry\'s style. '
          'Terry is Gen-Z, uses slang like "bruh", "lowkey", "no cap". '
          'Keep it under 2 sentences.'),
    ]);
    return response.text ?? 'Bruh, I got nothing...';
  }

  /// Generate a Nigel-style roast
  static Future<String> generateNigelRoast(String topic) async {
    final response = await _model.generateContent([
      Content.text(
          'Generate a short, dry-wit roast about "$topic" in Nigel\'s style. '
          'Nigel is British, refined, uses phrases like "rather", "indeed", "curious". '
          'Keep it under 2 sentences.'),
    ]);
    return response.text ?? 'Rather unfortunate, that...';
  }

  /// Generate dialogue between Terry and Nigel
  static Future<String> generateBanter(String topic) async {
    final response = await _model.generateContent([
      Content.text(
          'Generate a quick back-and-forth between Terry and Nigel about "$topic". '
          'Format: Terry: [line]\\nNigel: [line]\\nTerry: [line]\\n'
          'Keep each line short and punchy.'),
    ]);
    return response.text ?? 'Terry: Bruh...\nNigel: Indeed.';
  }
}
