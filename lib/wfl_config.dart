/// WFL Configuration - API keys and settings
///
/// Set your keys here or via environment variables
class WFLConfig {
  /// Shared secret for local Node control server (WebSocket/REST).
  ///
  /// Set with Flutter build/run arg:
  /// `--dart-define=WFL_CONTROL_TOKEN=...`
  ///
  /// If empty, the Node control servers will typically run without auth.
  static String controlToken = const String.fromEnvironment(
    'WFL_CONTROL_TOKEN',
    defaultValue: '',
  );

  // Claude API key for vision roasts
  static String claudeApiKey = const String.fromEnvironment(
    'CLAUDE_API_KEY',
    defaultValue: '',
  );

  // ElevenLabs API key for TTS
  static String elevenLabsKey = const String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: '',
  );

  // OpenAI API key for Whisper transcription (live mic mode)
  static String openAIKey = const String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  // YOUR cloned voice IDs from ElevenLabs
  // Go to elevenlabs.io → Voices → Add Voice → Instant Voice Clone
  // Upload YOUR recordings, get the voice_id, paste here
  static String terryVoiceId = 'YOUR_TERRY_VOICE_ID';  // Aussie twang
  static String nigelVoiceId = 'YOUR_NIGEL_VOICE_ID';  // British crisp

  // Set API keys at runtime
  static void setKeys(String claude, String elevenlabs, {String? openai}) {
    claudeApiKey = claude;
    elevenLabsKey = elevenlabs;
    if (openai != null) openAIKey = openai;
  }

  // Set YOUR cloned voice IDs
  static void setVoices(String terry, String nigel) {
    terryVoiceId = terry;
    nigelVoiceId = nigel;
  }

  // Check if auto-roast is enabled
  static bool get autoRoastEnabled =>
      claudeApiKey.isNotEmpty && elevenLabsKey.isNotEmpty;

  // Check if live mic mode is enabled (needs Whisper)
  static bool get liveMicEnabled =>
      autoRoastEnabled && openAIKey.isNotEmpty;

  // Agent Chat API Configuration
  // Free providers (no key required): 'ollama', 'local'
  // Free tier with key: 'groq', 'together', 'openrouter'
  // Premium: 'claude', 'openai'
  static String agentProvider = const String.fromEnvironment(
    'AGENT_PROVIDER',
    defaultValue: 'groq', // Groq has free tier with llama models
  );

  // Groq API key (free tier available at console.groq.com)
  static String groqApiKey = const String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  // Together AI key (free tier at api.together.xyz)
  static String togetherApiKey = const String.fromEnvironment(
    'TOGETHER_API_KEY',
    defaultValue: '',
  );

  // OpenRouter key (free models at openrouter.ai)
  static String openRouterApiKey = const String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );

  // Local Ollama URL (default localhost)
  static String ollamaUrl = const String.fromEnvironment(
    'OLLAMA_URL',
    defaultValue: 'http://localhost:11434',
  );

  // Model selection per provider
  static String groqModel = 'llama-3.3-70b-versatile'; // Free on Groq
  static String togetherModel = 'meta-llama/Llama-3.2-3B-Instruct-Turbo';
  static String openRouterModel = 'meta-llama/llama-3.2-3b-instruct:free';
  static String ollamaModel = 'llama3.2';
  static String claudeModel = 'claude-3-haiku-20240307';

  // Check if agent has any API available
  static bool get agentEnabled {
    switch (agentProvider) {
      case 'claude':
        return claudeApiKey.isNotEmpty;
      case 'groq':
        return groqApiKey.isNotEmpty;
      case 'together':
        return togetherApiKey.isNotEmpty;
      case 'openrouter':
        return openRouterApiKey.isNotEmpty;
      case 'ollama':
      case 'local':
        return true; // Local doesn't need key
      default:
        return false;
    }
  }

  // Get current API key based on provider
  static String get agentApiKey {
    switch (agentProvider) {
      case 'claude':
        return claudeApiKey;
      case 'groq':
        return groqApiKey;
      case 'together':
        return togetherApiKey;
      case 'openrouter':
        return openRouterApiKey;
      default:
        return '';
    }
  }

  // Set agent provider and keys at runtime
  static void setAgentConfig(String provider, {String? apiKey}) {
    agentProvider = provider;
    if (apiKey != null) {
      switch (provider) {
        case 'claude':
          claudeApiKey = apiKey;
          break;
        case 'groq':
          groqApiKey = apiKey;
          break;
        case 'together':
          togetherApiKey = apiKey;
          break;
        case 'openrouter':
          openRouterApiKey = apiKey;
          break;
      }
    }
  }
}
