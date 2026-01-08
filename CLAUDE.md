# CLAUDE.md

## Project Overview

**WFL Viewer** (v3.0.0) - A Flutter-based animation viewer and "Auto-Roast Pipeline" featuring two animated characters (Terry and Nigel) who react to and roast user-provided content using AI vision and text-to-speech.

## Tech Stack

- **Flutter/Dart** (SDK >=3.0.0 <4.0.0)
- **Rive** (0.13+) - Character animations with Data Binding API for lip-sync
- **Claude API** - Vision AI for generating sarcastic roasts of images/videos
- **ElevenLabs** - Text-to-speech with custom cloned voices
- **OpenAI Whisper** - Audio transcription for live mic mode
- **FFmpeg Kit** - Video export/composition
- **WebSocket** - Server control communication

## Architecture

```
lib/
├── main.dart              # App entry, asset precaching
├── wfl_boot.dart          # PIN code entry screen (skipped in release mode)
├── wfl_animator.dart      # Main cockpit UI with character animations (large file)
├── wfl_controller.dart    # Animation controller, WFLAutoRoast pipeline, video clipper
├── wfl_config.dart        # API keys configuration (env vars or runtime)
├── wfl_data_binding.dart  # Rive StateMachine inputs for lip-sync
├── wfl_websocket.dart     # WebSocket client for server commands
├── wfl_uploader.dart      # Upload functionality
├── wfl_focus_mode.dart    # Focus mode feature
├── wfl_animations.dart    # Character idle animations (simple_animations)
├── wfl_image_resizer.dart # Image resizing utilities
├── dialogue_queue.dart    # Dialogue line queue with emotions
├── character_prompts.dart # Character catchphrases and prompts
├── sound_effects.dart     # Comedy sound effects for Show Mode
├── mouth_painter.dart     # Custom mouth shape painting
├── rive_path_effect.dart  # Rive path effects manager
└── record_stub.dart       # Stub for mic recording (Windows build)
```

## Characters

- **Terry** - Australian alien, naive kid discovering sarcasm, excited energy
  - Voice ID: `KpQWWCkZkOBFFyP60zEy`
  - Catchphrases: "Crikey!", "Strewth!", "Fair dinkum!"

- **Nigel** - British robot, dry and utterly unimpressed, deadpan delivery
  - Voice ID: `NiKs4Dt6LzgyiBQJJa2y`
  - Style: "Indeed.", "Processing...", "Error 404."

## Configuration

API keys can be set via environment variables or at runtime:

```dart
// Environment variables
CLAUDE_API_KEY=your_key
ELEVENLABS_API_KEY=your_key
OPENAI_API_KEY=your_key  // Optional, for live mic mode

// Or at runtime
WFLConfig.setKeys('claude_key', 'elevenlabs_key', openai: 'openai_key');
WFLConfig.setVoices('terry_voice_id', 'nigel_voice_id');
```

## Development Commands

```bash
# Get dependencies
flutter pub get

# Run in debug mode (requires PIN: 0711)
flutter run

# Run in release mode (skips PIN entry)
flutter run --release

# Build for Windows
flutter build windows

# Analyze code
flutter analyze
```

## Key Features

1. **Auto-Roast Pipeline** - Drop image/video → Claude vision generates roast → ElevenLabs TTS → Character lip-syncs
2. **Live Mic Mode** - Record audio → Whisper transcription → Generate comeback → TTS response
3. **Three Portholes** - Video windows for content display
4. **Dialogue Queue** - Sequential dialogue with emotions and reactions
5. **React Mode** - Toggle roast + lip-sync vs clean playback
6. **WebSocket Control** - Remote server commands via ws://127.0.0.1:3000

## Lip-Sync System

Uses Rive StateMachine inputs:
- `lipShape` (0-8): Mouth shapes for phonemes (x=closed, a=wide, e=smile, etc.)
- `isTalking` (bool): Whether character is speaking
- `focusX` (double): Eye focus direction (-1 left, 0 center, 1 right)

## Assets Structure

```
assets/
├── wfl.riv                    # Main Rive animation file
├── backgrounds/               # Background images
├── characters/
│   ├── terry/
│   │   ├── layers/           # Body components
│   │   ├── mouth_shapes/     # Mouth PNGs
│   │   └── eyes/             # Eye states
│   └── nigel/
│       ├── layers/
│       ├── mouth_shapes/
│       └── eyes/
├── audio/                     # Voice audio files
├── sfx/                       # Sound effects
│   └── background/           # Background music
└── path_effects/             # Custom Lua path effects
```

## Notes

- PIN code in debug mode: `0711`
- Release mode auto-launches without PIN (Windows UAC workaround)
- Mic recording is stubbed for Windows builds
- Uses `flutter_lints` for code analysis
