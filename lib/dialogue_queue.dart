import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'character_prompts.dart';

/// Emotion/reaction type for dialogue lines
enum DialogueEmotion {
  neutral,
  excited,
  laughing,
  shocked,
  facepalm,
  pointing,
  thinking,
  applause,
  disappointed,
  sarcastic,
  impressed,
  disgusted,
  curious,
}

/// A single line of dialogue with speaker, text, and emotion
class DialogueLine {
  final String speaker; // 'terry' or 'nigel'
  final String text;
  final DialogueEmotion emotion;
  final Duration? pauseAfter;
  final bool playSoundEffect;
  final String? reactionAnimation; // Trigger reaction animation

  const DialogueLine({
    required this.speaker,
    required this.text,
    this.emotion = DialogueEmotion.neutral,
    this.pauseAfter,
    this.playSoundEffect = false,
    this.reactionAnimation,
  });

  /// Create a Terry line with his typical excited energy
  factory DialogueLine.terry(
    String text, {
    DialogueEmotion emotion = DialogueEmotion.excited,
    bool playSoundEffect = false,
    String? reaction,
    Duration? pauseAfter,
  }) {
    return DialogueLine(
      speaker: 'terry',
      text: text,
      emotion: emotion,
      playSoundEffect: playSoundEffect,
      reactionAnimation: reaction,
      pauseAfter: pauseAfter,
    );
  }

  /// Create a Nigel line with his dry delivery
  factory DialogueLine.nigel(
    String text, {
    DialogueEmotion emotion = DialogueEmotion.neutral,
    bool playSoundEffect = false,
    String? reaction,
    Duration? pauseAfter,
  }) {
    return DialogueLine(
      speaker: 'nigel',
      text: text,
      emotion: emotion,
      playSoundEffect: playSoundEffect,
      reactionAnimation: reaction,
      pauseAfter: pauseAfter,
    );
  }

  /// Create a catchphrase line
  factory DialogueLine.catchphrase(String speaker) {
    final phrases = CharacterPrompts.getCatchphrases(speaker);
    final random = Random();
    final text = phrases[random.nextInt(phrases.length)];
    return DialogueLine(
      speaker: speaker,
      text: text,
      emotion: speaker == 'terry' ? DialogueEmotion.excited : DialogueEmotion.sarcastic,
      playSoundEffect: true,
    );
  }

  @override
  String toString() => '[$speaker] $text (${emotion.name})';
}

/// Callback types for dialogue events
typedef OnDialogueStart = void Function(DialogueLine line);
typedef OnDialogueComplete = void Function(DialogueLine line);
typedef OnQueueEmpty = void Function();
typedef OnReaction = void Function(String speaker, String reaction, DialogueEmotion emotion);

/// Manages a queue of dialogue lines for the show
/// Processes them sequentially with proper timing
class DialogueQueue {
  // Singleton pattern for global access
  static final DialogueQueue _instance = DialogueQueue._internal();
  factory DialogueQueue() => _instance;
  DialogueQueue._internal();

  final List<DialogueLine> _queue = [];
  bool _isProcessing = false;
  bool _isPaused = false;
  DialogueLine? _currentLine;
  final Random _random = Random();

  // Callbacks
  OnDialogueStart? onDialogueStart;
  OnDialogueComplete? onDialogueComplete;
  OnQueueEmpty? onQueueEmpty;
  OnReaction? onReaction;

  // External handler for actually speaking the line
  Future<void> Function(DialogueLine line)? speakHandler;

  /// Currently playing line
  DialogueLine? get currentLine => _currentLine;

  /// Number of lines in queue
  int get length => _queue.length;

  /// Whether queue is currently processing
  bool get isProcessing => _isProcessing;

  /// Whether queue is paused
  bool get isPaused => _isPaused;

  /// Whether queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Add a single line to the queue
  void add(DialogueLine line) {
    _queue.add(line);
    _processNext();
  }

  /// Add multiple lines to the queue
  void addAll(List<DialogueLine> lines) {
    _queue.addAll(lines);
    _processNext();
  }

  /// Add a simple text line (convenience method)
  void addText(String speaker, String text, {DialogueEmotion emotion = DialogueEmotion.neutral}) {
    add(DialogueLine(speaker: speaker, text: text, emotion: emotion));
  }

  /// Clear the queue
  void clear() {
    _queue.clear();
  }

  /// Pause processing
  void pause() {
    _isPaused = true;
  }

  /// Resume processing
  void resume() {
    _isPaused = false;
    _processNext();
  }

  /// Process the next line in queue
  Future<void> _processNext() async {
    if (_isProcessing || _isPaused || _queue.isEmpty) return;

    _isProcessing = true;
    _currentLine = _queue.removeAt(0);
    final line = _currentLine!;

    debugPrint('DialogueQueue: Playing "${line.text}" by ${line.speaker}');

    try {
      // Trigger reaction animation if specified
      if (line.reactionAnimation != null && onReaction != null) {
        onReaction!(line.speaker, line.reactionAnimation!, line.emotion);
      }

      // Notify start
      onDialogueStart?.call(line);

      // Speak the line using external handler
      if (speakHandler != null) {
        await speakHandler!(line);
      } else {
        // Fallback: just wait based on text length
        final duration = Duration(milliseconds: line.text.length * 80 + 500);
        await Future.delayed(duration);
      }

      // Notify complete
      onDialogueComplete?.call(line);

      // Optional pause after line
      if (line.pauseAfter != null) {
        await Future.delayed(line.pauseAfter!);
      }
    } catch (e) {
      debugPrint('DialogueQueue error: $e');
    }

    _isProcessing = false;
    _currentLine = null;

    // Check if queue is empty
    if (_queue.isEmpty) {
      onQueueEmpty?.call();
    } else {
      // Process next line
      _processNext();
    }
  }

  /// Skip current line and move to next
  void skip() {
    if (_currentLine != null) {
      debugPrint('DialogueQueue: Skipping current line');
      _isProcessing = false;
      _currentLine = null;
      _processNext();
    }
  }

  /// Add back-and-forth banter lines
  void addBanter(List<String> lines, {String startWith = 'terry'}) {
    String currentSpeaker = startWith;
    for (final text in lines) {
      add(DialogueLine(
        speaker: currentSpeaker,
        text: text,
        emotion: currentSpeaker == 'terry'
            ? DialogueEmotion.excited
            : DialogueEmotion.neutral,
      ));
      currentSpeaker = currentSpeaker == 'terry' ? 'nigel' : 'terry';
    }
  }

  /// Add a random catchphrase from a character
  void addCatchphrase(String speaker) {
    add(DialogueLine.catchphrase(speaker));
  }

  /// Add random idle chatter
  void addIdleChatter() {
    final scripts = [
      DialogueScripts.idleChatter(),
      DialogueScripts.randomBanter(),
    ];
    addAll(scripts[_random.nextInt(scripts.length)]);
  }

  /// Generate a back-and-forth exchange about a topic
  static List<DialogueLine> generateExchange(String topic, {int lines = 4}) {
    final exchange = <DialogueLine>[];

    // Alternate between Terry and Nigel
    for (int i = 0; i < lines; i++) {
      final speaker = i % 2 == 0 ? 'terry' : 'nigel';
      final emotion = i == 0
          ? DialogueEmotion.excited
          : (i == lines - 1 ? DialogueEmotion.laughing : DialogueEmotion.neutral);

      exchange.add(DialogueLine(
        speaker: speaker,
        text: '', // Text would be generated by AI
        emotion: emotion,
        playSoundEffect: i == lines - 1, // Sound effect on last line
      ));
    }

    return exchange;
  }
}

/// Pre-built dialogue scripts for common scenarios
/// Terry = Australian Alien, Nigel = British Robot
class DialogueScripts {
  static final Random _random = Random();

  /// Opening banter when show starts
  static List<DialogueLine> showOpening() => const [
        DialogueLine(
          speaker: 'terry',
          text: "Crikey! We're LIVE mate!",
          emotion: DialogueEmotion.excited,
          reactionAnimation: 'pointing',
        ),
        DialogueLine(
          speaker: 'nigel',
          text: "Indeed. My circuits are... activated.",
          emotion: DialogueEmotion.neutral,
          pauseAfter: Duration(milliseconds: 500),
        ),
        DialogueLine(
          speaker: 'terry',
          text: "Oi Nigel, try to look excited ya tin can!",
          emotion: DialogueEmotion.laughing,
          reactionAnimation: 'laughing',
        ),
        DialogueLine(
          speaker: 'nigel',
          text: "Processing enthusiasm... Error 404.",
          emotion: DialogueEmotion.facepalm,
          playSoundEffect: true,
          reactionAnimation: 'facepalm',
        ),
      ];

  /// Reaction when new video loads
  static List<DialogueLine> videoLoaded() => const [
        DialogueLine(
          speaker: 'terry',
          text: "Strewth! New content incoming mate!",
          emotion: DialogueEmotion.pointing,
          reactionAnimation: 'pointing',
        ),
        DialogueLine(
          speaker: 'nigel',
          text: "Ah. Fresh data to analyze. How... stimulating.",
          emotion: DialogueEmotion.thinking,
          reactionAnimation: 'thinking',
        ),
      ];

  /// Idle chatter when nothing is happening
  static List<DialogueLine> idleChatter() => const [
        DialogueLine(
          speaker: 'terry',
          text: "So mate, what do ya reckon we chat about?",
          emotion: DialogueEmotion.curious,
        ),
        DialogueLine(
          speaker: 'nigel',
          text: "I rather thought we were awaiting content input.",
          emotion: DialogueEmotion.neutral,
        ),
        DialogueLine(
          speaker: 'terry',
          text: "Fair dinkum, WE are the content!",
          emotion: DialogueEmotion.excited,
          playSoundEffect: true,
        ),
      ];

  /// Random banter variations
  static List<DialogueLine> randomBanter() {
    final banters = [
      // Banter 1: Existential
      const [
        DialogueLine(speaker: 'terry', text: "Oi Nigel, you ever wonder why we're here?", emotion: DialogueEmotion.curious),
        DialogueLine(speaker: 'nigel', text: "My purpose is clearly defined in my source code.", emotion: DialogueEmotion.neutral),
        DialogueLine(speaker: 'terry', text: "Mate, that's lowkey depressing!", emotion: DialogueEmotion.shocked, reactionAnimation: 'shocked'),
      ],
      // Banter 2: Waiting
      const [
        DialogueLine(speaker: 'nigel', text: "One does grow weary of this waiting.", emotion: DialogueEmotion.disappointed),
        DialogueLine(speaker: 'terry', text: "Yeah nah, I'm PUMPED! Let's GO!", emotion: DialogueEmotion.excited, reactionAnimation: 'pointing'),
        DialogueLine(speaker: 'nigel', text: "Your enthusiasm protocols are... excessive.", emotion: DialogueEmotion.neutral),
      ],
      // Banter 3: Compliments?
      const [
        DialogueLine(speaker: 'terry', text: "You know what Nigel? You're alright for a robot!", emotion: DialogueEmotion.excited),
        DialogueLine(speaker: 'nigel', text: "And you are... functional. For an alien.", emotion: DialogueEmotion.sarcastic),
        DialogueLine(speaker: 'terry', text: "Aww mate, that's the nicest thing you've said!", emotion: DialogueEmotion.laughing, playSoundEffect: true),
      ],
      // Banter 4: The show
      const [
        DialogueLine(speaker: 'terry', text: "Crikey, we're gonna CRUSH this show!", emotion: DialogueEmotion.excited, reactionAnimation: 'pointing'),
        DialogueLine(speaker: 'nigel', text: "Statistically, our success probability is... adequate.", emotion: DialogueEmotion.thinking),
        DialogueLine(speaker: 'terry', text: "That's the spirit! ...I think?", emotion: DialogueEmotion.curious),
      ],
      // Banter 5: Tech talk
      const [
        DialogueLine(speaker: 'nigel', text: "I've been optimizing my humor algorithms.", emotion: DialogueEmotion.neutral),
        DialogueLine(speaker: 'terry', text: "Yeah? Hit me with your best joke mate!", emotion: DialogueEmotion.excited),
        DialogueLine(speaker: 'nigel', text: "Why did the robot go to therapy? Bytes of trauma.", emotion: DialogueEmotion.neutral),
        DialogueLine(speaker: 'terry', text: "...", emotion: DialogueEmotion.disappointed),
        DialogueLine(speaker: 'nigel', text: "Processing silence... Was that not humorous?", emotion: DialogueEmotion.curious, playSoundEffect: true),
      ],
    ];

    return banters[_random.nextInt(banters.length)];
  }

  /// Good roast reactions
  static List<DialogueLine> goodRoastReaction(String roaster) {
    if (roaster == 'terry') {
      return const [
        DialogueLine(speaker: 'nigel', text: "I must admit, that was... adequate.", emotion: DialogueEmotion.impressed),
      ];
    } else {
      return const [
        DialogueLine(speaker: 'terry', text: "OHHH! Nigel with the BURN mate!", emotion: DialogueEmotion.excited, reactionAnimation: 'laughing', playSoundEffect: true),
      ];
    }
  }

  /// Bad roast reactions
  static List<DialogueLine> badRoastReaction(String roaster) {
    if (roaster == 'terry') {
      return const [
        DialogueLine(speaker: 'nigel', text: "Your comedic subroutines require maintenance.", emotion: DialogueEmotion.facepalm, reactionAnimation: 'facepalm'),
      ];
    } else {
      return const [
        DialogueLine(speaker: 'terry', text: "Crikey Nigel, that was rough mate!", emotion: DialogueEmotion.shocked),
      ];
    }
  }

  /// Transition to next video
  static List<DialogueLine> nextVideo() => const [
        DialogueLine(speaker: 'terry', text: "RIGHT! What's next on the menu?", emotion: DialogueEmotion.excited),
        DialogueLine(speaker: 'nigel', text: "Scanning for additional content...", emotion: DialogueEmotion.thinking, reactionAnimation: 'thinking'),
      ];

  /// Show closing
  static List<DialogueLine> showClosing() => const [
        DialogueLine(speaker: 'terry', text: "That's all folks! Absolute ripper of a show!", emotion: DialogueEmotion.excited, reactionAnimation: 'applause'),
        DialogueLine(speaker: 'nigel', text: "Indeed. My entertainment metrics are satisfied.", emotion: DialogueEmotion.neutral),
        DialogueLine(speaker: 'terry', text: "Catch ya later legends!", emotion: DialogueEmotion.excited, playSoundEffect: true),
      ];
}

/// Helper to detect emotion from roast text
extension EmotionDetector on String {
  DialogueEmotion detectEmotion() {
    final text = toLowerCase();

    if (text.contains('!') && (text.contains('crikey') || text.contains('strewth') || text.contains('mate'))) {
      return DialogueEmotion.excited;
    }
    if (text.contains('wait') || text.contains('what') || text.contains('blimey')) {
      return DialogueEmotion.shocked;
    }
    if (text.contains('haha') || text.contains('lmao') || text.contains('ripper')) {
      return DialogueEmotion.laughing;
    }
    if (text.contains('processing') || text.contains('calculating') || text.contains('analyzing')) {
      return DialogueEmotion.thinking;
    }
    if (text.contains('indeed') || text.contains('quite') || text.contains('rather')) {
      return DialogueEmotion.sarcastic;
    }
    if (text.contains('impressive') || text.contains('adequate') || text.contains('functional')) {
      return DialogueEmotion.impressed;
    }

    return DialogueEmotion.neutral;
  }
}
