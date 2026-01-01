/// WFL Configuration - API keys and settings
///
/// Set your keys here or via environment variables
class WFLConfig {
  // Claude API key for vision roasts
  static String claudeApiKey = const String.fromEnvironment(
    'CLAUDE_API_KEY',
    defaultValue: '', // Set via environment variable
  );

  // ElevenLabs API key for TTS
  static String elevenLabsKey = const String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: '', // Set via environment variable
  );

  // OpenAI API key for Whisper transcription (live mic mode)
  static String openAIKey = const String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '', // Set via environment variable
  );

  // YOUR cloned voice IDs from ElevenLabs
  // Go to elevenlabs.io → Voices → Add Voice → Instant Voice Clone
  // Upload YOUR recordings, get the voice_id, paste here
  static String terryVoiceId = 'KpQWWCkZkOBFFyP60zEy';  // Terry voice (swapped)
  static String nigelVoiceId = 'NiKs4Dt6LzgyiBQJJa2y';  // Nigel voice (swapped)

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
}
