# 🎙️ Speachy — macOS Speech-to-Text Menubar App

A lightweight, professional macOS menubar application for voice-to-text transcription with formal text rewriting powered by OpenAI's Whisper API and GPT-4o-mini.

## Features

- **Two Recording Modes:**
  - Normal dictation (Ctrl+Shift+Space) — Direct transcription
  - Formal dictation (Ctrl+Shift+F) — Transcription + formal rewriting
- **Menubar Integration** — Runs quietly in macOS menubar as a simple mic icon
- **No Dock Icon** — Minimal UI footprint
- **Multi-Language Support** — Auto-detection or manual selection (German, English, French, Spanish, etc.)
- **Global Hotkeys** — Keyboard shortcuts work system-wide
- **Real-Time Transcription** — Uses OpenAI's latest transcription models
- **Accessibility-First** — Automatically inserts text at cursor position in any app
- **Privacy-Focused** — API keys stored locally, never transmitted elsewhere

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)
- Swift 5.9+
- OpenAI API key (with Whisper and GPT-4o-mini access)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/speachy.git
cd speachy
```

### 2. Create Xcode Project

Open Xcode and create a new **macOS App** project:
- **Product Name:** Speachy
- **Organization Identifier:** com.yourdomain.speachy (or similar)
- **Minimum Deployment:** macOS 14.0
- **Interface:** SwiftUI

### 3. Add Swift Source Files

Add all Swift files from this repository to the Xcode project:
- `VoiceScribeApp.swift`
- `AppState.swift`
- `AudioRecorder.swift`
- `WhisperService.swift`
- `TextInserter.swift`
- `RewriteService.swift`
- `HotkeyManager.swift`
- `SettingsView.swift`
- `MenuBarView.swift`

### 4. Configure Info.plist

Add these key-value pairs to your `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Speachy needs network access to communicate with OpenAI API</string>

<key>NSBonjourServices</key>
<array></array>

<key>NSLocalNetworkUsageDescription</key>
<string>Speachy uses the network to transcribe audio via OpenAI Whisper API</string>

<key>NSAccessibilityUsageDescription</key>
<string>Speachy requires Accessibility access to register global hotkeys and insert text at the cursor position</string>

<key>NSMicrophoneUsageDescription</key>
<string>Speachy requires microphone access to record your voice</string>
```

Alternatively, use the provided `Info.plist` file.

### 5. Build & Run

```bash
# In Xcode: Press Cmd+R to build and run
# Or from Terminal:
xcodebuild -scheme Speachy -destination 'platform=macOS' build run
```

## Configuration

### Getting an OpenAI API Key

1. Visit [OpenAI Platform](https://platform.openai.com)
2. Sign up or log in
3. Navigate to **API Keys** → **Create new secret key**
4. Copy the key (keep it safe!)
5. Paste it in Speachy's Settings window

### Setting Permissions

Speachy requires two system permissions:

#### 1. Accessibility Permission (for hotkeys and text insertion)
- Open **System Settings** → **Privacy & Security** → **Accessibility**
- Find and add **Speachy** (or Xcode if running from Xcode)
- Grant full access

#### 2. Microphone Permission (for recording)
- Open **System Settings** → **Privacy & Security** → **Microphone**
- Find and add **Speachy**
- Grant access

## Usage

### Start Recording

**Normal Mode:**
1. Press `Ctrl+Shift+Space` (or use Menu → Normal Dictation)
2. Speak clearly
3. Press `Ctrl+Shift+Space` again to stop
4. Transcribed text appears at cursor position

**Formal Mode:**
1. Press `Ctrl+Shift+F` (or use Menu → Formal Dictation)
2. Speak
3. Press `Ctrl+Shift+F` to stop
4. Text is transcribed, formalized, and inserted

### Configure Settings

Click the microphone icon in the menubar and select **Settings**:
- **OpenAI API Key** — Paste your API key here
- **Whisper Model** — Choose transcription model (GPT-4o Transcribe recommended)
- **Language** — Auto-detect or specify (de, en, fr, es, etc.)
- **Test Connection** — Verify your API key works

## Architecture

### Component Flow

```
Menubar Icon
    ↓
HotkeyManager (listens for Ctrl+Shift+Space/F)
    ↓
AppState (state machine)
    ↓
AudioRecorder (captures mic input → WAV)
    ↓
WhisperService (sends to OpenAI API)
    ↓
RewriteService (formal mode only)
    ↓
TextInserter (pastes at cursor)
```

### Key Components

- **VoiceScribeApp.swift** — App entry point, menubar UI, AppDelegate
- **AppState.swift** — State machine managing recording, transcription, and modes
- **AudioRecorder.swift** — Captures audio via AVAudioEngine, saves as WAV
- **WhisperService.swift** — Handles OpenAI Whisper API calls with multipart forms
- **RewriteService.swift** — Applies formal text transformation (GPT-4o-mini powered)
- **TextInserter.swift** — Uses NSPasteboard + CGEvent to insert text at cursor
- **HotkeyManager.swift** — Global keyboard event listener for hotkey detection
- **SettingsView.swift** — Configuration UI in SwiftUI
- **MenuBarView.swift** — Menubar dropdown menu

## API Details

### OpenAI Whisper API

Speachy uses the **OpenAI Audio Transcriptions API** (latest models: `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`, `whisper-1`).

- **Endpoint:** `POST https://api.openai.com/v1/audio/transcriptions`
- **Audio Format:** WAV, 16kHz mono, 16-bit PCM
- **Max Duration:** ~25 MB / 6 minutes per request
- **Authentication:** Bearer token in Authorization header

### GPT-4o-mini for Formal Rewriting

Formal mode uses local heuristics for fast text transformation. For advanced rewriting, the service can be extended to use Claude API or OpenAI's ChatGPT API.

## Privacy & Security

- **API Keys** are stored locally in macOS `UserDefaults`
- **Audio** is transmitted only to OpenAI's API endpoints (https://api.openai.com)
- **No telemetry** or analytics collected by Speachy
- **No cloud storage** — recordings are temporary files cleaned up after transcription
- **Open source** — Review the code yourself for security

## Troubleshooting

### "Accessibility Permission Required"

The app shows a permission request on first launch. To fix:
1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Add Speachy to the list
3. Restart the app

### Hotkeys Don't Work

- Verify Accessibility permission is granted
- Check if another app uses the same hotkey
- Restart the application
- Try in a different application (e.g., Notes, Mail)

### "API Connection Failed"

- Double-check your OpenAI API key (Settings → Test Connection)
- Verify internet connection
- Check if your OpenAI account has access to Whisper API
- View full error in app's status text

### No Audio Captured

- Ensure microphone is properly connected
- Check system microphone in **System Settings** → **Sound**
- Verify **Microphone** permission is granted
- Restart the app

### Text Not Inserted

- Ensure **Accessibility** permission is granted
- Click in a text field before recording (to set focus)
- Test with a standard app like Notes or TextEdit
- Verify Cmd+V (paste) works manually in the target app

## Development

### Build from Source

```bash
git clone https://github.com/yourusername/speachy.git
cd speachy
open VoiceScribe.xcodeproj  # or create new Xcode project and add files
```

### Code Style

- Comments in English (some legacy German comments from initial development)
- `MARK:` section markers for organization
- async/await for asynchronous operations
- Observable/ObservationObject for state management
- SwiftUI for all UI

### Future Enhancements

- [ ] Custom hotkey configuration
- [ ] Floating recording indicator with audio levels
- [ ] Support for additional transcription services
- [ ] Expanded formal rewriting via Claude API
- [ ] Keyboard shortcut rebinding in settings
- [ ] Output to file option

## License

MIT License — See [LICENSE](LICENSE) file for details.

Copyright © 2025 Luis Gärtner

## Support

For issues, questions, or feature requests, please open an issue on GitHub or contact the author.

---

Made with ❤️ by Luis Gärtner
