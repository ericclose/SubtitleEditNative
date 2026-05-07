# Subtitle Edit Native (macOS)

A high-performance, native macOS subtitle editor built with **SwiftUI** and **.NET 9 Native AOT**. This project brings the powerful core logic of Subtitle Edit to the Mac with a premium, system-integrated user experience.

## 🚀 Key Features

- **Interactive Timeline**: Precision waveform editing with drag-and-drop start/end point adjustment.
- **AI Speech-to-Text**: Real-world integration with `whisper.cpp` for automated subtitle generation from video.
- **Native Spell Check**: Full integration with macOS `NSSpellChecker` for language-aware error detection and smart suggestions.
- **Translation Mode**: Dual-column side-by-side editing for original and translated text.
- **Style Preview**: Real-time rendering of subtitle styles (fonts, colors, outlines) directly in the editor.
- **Professional Core**: Leverages the industry-standard `LibSE` logic via a high-performance C-Bridge.
- **Full Undo/Redo**: Comprehensive history management for all editing operations.

## 🛠 Tech Stack

- **Frontend**: SwiftUI (macOS 13+)
- **Backend Core**: .NET 9.0 (Native AOT)
- **Bridging**: C-Bridge with `dlopen`/`dlsym` for low-latency communication.
- **Graphics**: SkiaSharp for fast waveform rendering.
- **Video/Audio**: `libmpv` and `ffmpeg` integration.

## 📋 Prerequisites

- **.NET 9 SDK**: For building the core logic.
- **Xcode 15+**: For SwiftUI compilation.
- **Homebrew Dependencies**:
  ```bash
  brew install ffmpeg libmpv whisper-cpp
  ```

## 🏗 Build & Package

To build the application and generate a DMG locally:

```bash
chmod +x package.sh
./package.sh
```

The resulting DMG will be located in the project root as `SubtitleEditNative_macOS_arm64.dmg`.

## 📂 Project Structure

```text
.
├── LibSE/                  # Core subtitle processing logic (Extracted from SE)
├── LibSEBridge/            # .NET 9 Native AOT Bridge (C-API)
│   ├── Exports.cs          # Native entry points for Swift interaction
│   └── MpvNative.cs        # libmpv interop definitions
├── Sources/                # SwiftUI Frontend (macOS Native)
│   ├── SubtitleBridge.swift # Swift wrapper for the .NET Bridge
│   ├── ContentView.swift    # Main editor UI & Waveform Timeline
│   ├── MainApp.swift       # App lifecycle & Menu configuration
│   ├── SettingsView.swift   # App preferences & Configuration UI
│   ├── SpellCheckView.swift # Native spell checker interface
│   ├── AutomationDialogs.swift # STT/Translation UI components
│   └── AppLogger.swift      # Centralized diagnostic logging
├── LibSEBridge.Tests/      # Unit tests for the .NET Bridge
├── Tests/                  # XCTest suite for the Swift app
├── package.sh              # Unified build & DMG packaging script
└── Package.swift           # Swift Package Manager configuration
```

## 📊 Comparison with Original Project

| Feature | Original Subtitle Edit | Subtitle Edit Native (This) |
| :--- | :--- | :--- |
| **Platform** | Windows/Linux/macOS (Cross) | **macOS (Native SwiftUI)** |
| **Runtime** | .NET (JIT) | **.NET 9 (Native AOT)** |
| **UI Aesthetics** | Functional (WinForms/Avalonia) | **Premium Apple Human Interface** |
| **Subtitle Engine** | LibSE (Core) | LibSE (Core via C-Bridge) |
| **Spell Check** | Hunspell | **macOS System (NSSpellChecker)** |
| **Audio Engine** | libmpv / VLC / DirectShow | **libmpv (High Performance)** |
| **Waveform** | Spectrogram / Peaks | **SkiaSharp Hardware Accelerated** |
| **STT** | Multiple (FasterWhisper, etc.) | Whisper.cpp (Integrated) |
| **OCR** | Tesseract / nOCR | **Apple Vision / Tesseract** |
| **Translation** | DeepL / Google / Bing | Google Translate / DeepL |
| **Diagnostics** | Basic logs | **Comprehensive System Logs** |

## 🎯 Missing Features & Roadmap

Currently, the following core features from the original project are being prioritized for implementation:

2. **Advanced Tools**: "Fix common errors" wizard and specialized sync tools.
3. **Audio Spectrogram**: Adding a frequency-domain view for precision timing.
4. **Cloud STT/TTS**: Expanding beyond local Whisper to support Azure/Google cloud services.
5. **Plugin System**: Porting the original C# plugin architecture to the Native bridge.

## 🤖 CI/CD Workflow

The project uses GitHub Actions for continuous integration:
1. **Test**: Runs .NET unit tests on every push.
2. **Build**: Compiles the .NET Bridge into a Native AOT library.
3. **Verify**: Ensures Swift code compatibility.
4. **Package**: Generates the macOS DMG.
5. **Release**: Automatically uploads the DMG to "Latest Release" when a version tag (e.g., `v1.0.0`) is pushed.

## ⚖️ License

Based on the original Subtitle Edit project. See LICENSE for details.
