# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native macOS SwiftUI app. Open and build with Xcode:

```bash
open Transcribe.xcodeproj
# Build: Cmd+B | Run: Cmd+R
```

The project requires macOS 26+ (Tahoe) and runs on Apple Silicon (M1+).

### Known Xcode 26 Build Issue

Building from Xcode's UI fails with `___llvm_profile_runtime` undefined symbol (yyjson, a pure C SPM transitive dependency of WhisperKit). This is an Xcode 26 bug where `CLANG_COVERAGE_MAPPING` defaults to YES and pure C SPM package targets get coverage instrumentation but miss `-fprofile-instr-generate` in their linker invocation. Build from the command line instead:

```bash
xcodebuild build -scheme Transcribe CLANG_COVERAGE_MAPPING=NO
```

**Important**: Always rebuild after making code changes to verify they compile and so the user can test them. Never skip the build step.

## Architecture

### Entry Point
- `Transcribe/TranscribeApp.swift` - Main app with SwiftUI lifecycle
- `Transcribe/AppDelegate.swift` - NSApplicationDelegate for status bar menu, file cleanup, window management

### Core Services

**Transcription Pipeline:**
- `WhisperKitService.swift` - Primary transcription engine using WhisperKit (CoreML). Handles model loading, transcription with progress streaming, and segment generation.
- `UnifiedTranscriptionService.swift` - Wraps WhisperKit; manages model state (`unloaded`/`loading`/`loaded`) and exposes a unified transcription interface.
- `TranscriptionService.swift` - Lightweight streaming wrapper around WhisperKitService

**Audio Processing:**
- `Services/AudioPreprocessor.swift` - Audio format conversion and preprocessing. Automatically extracts audio from video containers (`.mp4`, `.mov`, etc.) and converts non-native formats to 16kHz mono WAV using `AVAssetReader`/`AVAssetWriter`.

**System Audio Capture:**
- `Services/SystemAudioCaptureService.swift` - Captures system audio output using ScreenCaptureKit with optional microphone mixing. Two-phase architecture: monitoring (level meter, permission prompt) and recording (48kHz stereo float32 WAV). Supports mixing mic input via `AVAudioEngine` + `AudioRingBuffer` for meeting recording (both sides of a conversation). Includes CoreAudio device enumeration and selection for mic input.
- `Services/AudioRingBuffer.swift` - Thread-safe SPSC ring buffer using `os_unfair_lock`. Decouples mic capture (AVAudioEngine thread) from system audio capture (SCStream callback thread) during mixed recording.

**LLM Integration:**
- `Services/LLMService.swift` - Text processing via Ollama (or any OpenAI-compatible local server). Handles summarization, action points, and custom prompts.

**Model Support:**
- `kb_whisper-large-coreml` — KB Whisper Large (Swedish-optimized), ~3.1 GB. Bundled inside the app at `Transcribe/Resources/BundledModel/`.

The model is fetched from `mickekringai/kb-whisper-coreml` on HuggingFace **at build time** (via `scripts/download_bundled_model.sh` or git LFS) and compiled into the app bundle. No runtime download occurs.

### Key Managers
- `ModelManager.swift` - Model downloads, availability checking, and storage management
- `LanguageManager.swift` - Language selection (100+ languages)
- `SimplifiedManagers.swift` - Contains `SettingsManager` (app preferences, API keys, text processing prompts) and `KeychainHelper` (Keychain wrapper for API key storage)
- `LocalizationManager.swift` - UI localization (English/Swedish) via `localized(_:)` helper

### Views
- `ContentView.swift` - Main window with toolbar (file picker, recording, settings)
- `TranscriptionView.swift` - Transcription display with audio player, export, text processing, and "Sammanfatta" button
- `RecordingView.swift` - Built-in audio recording with live level meter, device selector, and playback
- `SystemAudioRecordingView.swift` - System audio capture with live level meter, record/stop, playback, and transcription
- `SammanfattaView.swift` - Meeting summarization with 5 curated Swedish LLM prompts (Mötesöversikt, Detaljerat protokoll, Deltagaranalys, Beslutslogg, Uppföljningsplan). Streaming result display with copy/save.
- `AboutView.swift` - Two-tab view: app info + scrollable Licenses tab (WhisperKit MIT license text). Opened via "About Transcribe..." in the status bar menu.
- `SettingsView.swift` - Preferences with model management, text processing prompts, LLM settings

### Data Models
- `TranscriptionModels.swift` - `TranscriptionResult`, `TranscriptionSegment`, `TextProcessingPrompt`, `AudioInputDevice`
- `AppState.swift` - Navigation state (`currentTranscriptionURL`, `showTranscriptionView`, `showRecordingView`, `showSystemAudioView`, `showSammanfattaView`, `sammanfattaText`). `openSammanfatta(text:)` opens the Sammanfatta screen with the given transcription text.

### File Storage & Security
All temporary files auto-cleanup on app quit and on startup (handles force-quit scenarios):
- Recordings: `~/Library/Caches/Transcribe/Recordings/`
- Cleanup handled in `AppDelegate.cleanupTemporaryFiles()`

API keys are stored in macOS Keychain via `KeychainHelper` (not UserDefaults). Legacy UserDefaults keys are migrated to Keychain on launch. No `print()` statements in production code — all debug logging has been removed.

## Key Patterns

### State Management
Uses `@EnvironmentObject` for global state:
- `AppState` - Navigation state (current file, view visibility)
- `SettingsManager` - User preferences (persisted via `@AppStorage` and Keychain)
- `TranscriptionManager` - Transcription queue

### Streaming Transcription
WhisperKit provides `AsyncThrowingStream<TranscriptionUpdate, Error>`:
```swift
for try await update in whisperKitService.transcribe(fileURL:modelId:language:) {
    // update.text, update.progress, update.segments, update.isComplete
}
```

### Audio Preprocessing
`TranscriptionService` automatically preprocesses files before passing them to WhisperKit:
- **Native formats** (`.wav`, `.mp3`, `.m4a`, `.flac`, `.aac`, `.aif`, `.aiff`, `.caf`) are passed directly
- **Video containers** (`.mp4`, `.mov`, `.mkv`, etc.) and other formats have their audio extracted to 16kHz mono WAV via `AVAssetReader`/`AVAssetWriter`
- Temporary files are cleaned up after transcription completes

### Recording
`RecordingView` contains `AudioRecorderManager` which handles:
- Microphone permission via `AVAudioApplication.shared.recordPermission` (modern API)
- Live audio level metering via `AVAudioEngine` input tap (pre-recording) and `AVAudioRecorder` metering (during recording)
- Audio input device selection via CoreAudio (`AudioObjectGetPropertyData`)
- Proper lifecycle management — engine taps removed before deallocation, no async self capture in `deinit`

### System Audio Recording
`SystemAudioRecordingView` uses `SystemAudioCaptureService` which wraps ScreenCaptureKit:
- **Permission**: `SCShareableContent.excludingDesktopWindows()` triggers the macOS "Screen & System Audio Recording" prompt on first use. Requires app restart after granting permission.
- **Monitoring**: `SCStream` with `capturesAudio = true` and minimal video (2x2px, 1fps) provides live audio level metering before recording starts.
- **Recording**: Audio buffers from `SCStreamOutput` callbacks written to WAV via `AVAudioFile`. Format: 48kHz stereo float32 non-interleaved (native ScreenCaptureKit output).
- **Mic mixing**: Optional "Include Microphone" toggle mixes mic input with system audio for meeting recording. `AVAudioEngine` captures mic, `AVAudioConverter` resamples to 48kHz stereo, `AudioRingBuffer` decouples the two threads. SCStream callback reads from ring buffer and mixes (sample addition + clamping). Dual level meters show system and mic levels separately.
- **Device selection**: When mic is enabled, CoreAudio device enumeration lets users pick their mic input. Same pattern as `RecordingView`'s `AudioRecorderManager`.
- **Transcription**: Recorded WAV passed to the same pipeline as microphone recordings — `AudioPreprocessor` converts to 16kHz mono for WhisperKit.
- **Entitlements**: Uses `com.apple.security.device.audio-input` (shared with microphone). `NSAudioCaptureUsageDescription` in Info.plist.
- **Temp files**: `~/tmp/Transcribe/SystemAudio/` — cleaned up by existing `AppDelegate.cleanupTemporaryFiles()`.

### Color System
Adaptive dark/light colors defined in `ColorExtensions.swift` using `NSColor(name:dynamicProvider:)`:
- `.primaryAccent` (`#3ECF8E` green), `.secondaryAccent`, `.tertiaryAccent` - Brand accent
- `.surfaceBackground`, `.cardBackground`, `.elevatedSurface` - Surface hierarchy
- `.textPrimary/Secondary/Tertiary` - Text hierarchy
- `LinearGradient.accentGradient`, `LinearGradient.primaryGradient`
- `.glassCard()` modifier - `ultraThinMaterial` + subtle border

### Theme
- Dark mode default, toggle via toolbar button
- `@AppStorage("appColorScheme")` stores `"dark"` or `"light"`
- Colors auto-adapt via `NSColor` dynamic provider — no `@Environment(\.colorScheme)` needed in views

### Text Processing Prompts
- `TextProcessingPrompt` model in `TranscriptionModels.swift` — `Identifiable`, `Codable`, `Equatable`
- CRUD in `SettingsManager` (`SimplifiedManagers.swift`) — JSON-encoded in UserDefaults
- 3 default Swedish prompts seeded on first launch (Sammanfattning, Åtgärdspunkter, Nyckelpunkter)
- Settings UI: `TextProcessingPromptsView` in `SettingsView.swift` under "Bearbeta text" sidebar section

### LLM Services
- **Ollama**: Local models via OpenAI-compatible `/v1/chat/completions` endpoint. Links to `ollama.com` when not running.
- Service layer: `LLMService.swift` handles streaming API calls. Host URL configured via `@AppStorage("ollamaHost")`.

## Dependencies (Package.swift)

- `WhisperKit` - On-device speech recognition (CoreML)

Keychain access uses the native Security framework (`SimplifiedManagers.swift` → `KeychainHelper`).

## Localization

Uses `localized(_:)` helper function (defined in `LocalizationManager.swift`). String files:
- `Transcribe/Resources/en.lproj/Localizable.strings` - English
- `Transcribe/Resources/sv.lproj/Localizable.strings` - Swedish

English is the default locale with full Swedish localization.

## Testing

```bash
# Run from Xcode: Cmd+U
# Or via xcodebuild:
xcodebuild test -scheme Transcribe -destination 'platform=macOS'
```

Test files:
- `TranscribeTests/TranscribeTests.swift`
- `TranscribeUITests/TranscribeUITests.swift`

## Known Issues / Future Work

- `localOnlyMode` setting exists in UI but is not enforced — network calls can still occur when enabled
- `nonisolated(unsafe) static let shared` on `LocalizationManager` suppresses concurrency warnings without fixing thread safety
- `SammanfattaView` prompt strings are hardcoded in Swedish (not using `localized()`)
